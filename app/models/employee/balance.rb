class Employee::Balance < ActiveRecord::Base
  belongs_to :employee
  belongs_to :time_off_category
  belongs_to :time_off
  belongs_to :time_off_policy

  belongs_to :balance_credit_addition, class_name: 'Employee::Balance'
  has_one :balance_credit_removal, class_name: 'Employee::Balance',
    foreign_key: 'balance_credit_addition_id', dependent: :destroy

  validates :employee,
    :time_off_category,
    :balance, :amount,
    :effective_at,
    :time_off_policy,
    presence: true
  validates :effective_at, uniqueness: { scope: [:time_off_policy, :employee] }
  validates :balance_credit_addition, presence: true, if: :removal_and_balancer?
  validate :time_off_policy_date, if: :time_off_policy
  validate :validity_date_later_than_effective_at, if: [:effective_at, :validity_date]

  before_validation :calculate_and_set_balance, if: :attributes_present?
  before_validation :find_effective_at, unless: :effective_at
  before_validation :check_if_credit_removal, if: :balance_credit_addition

  scope :employee_balances, -> (employee_id, time_off_policy_id) {
    where(employee_id: employee_id, time_off_policy: time_off_policy_id) }

  def balances
    self.class.employee_balances(employee_id, time_off_policy_id)
  end

  def last_in_category?
    id == employee.last_balance_in_category(time_off_category_id).id
  end

  def last_in_policy?
    id == employee.last_balance_in_policy(time_off_policy_id).id
  end

  def next_balance
    balances.where('effective_at > ?', now_or_effective_at).order(effective_at: :asc).first.try(:id)
  end

  def current_or_next_period
    [time_off_policy.current_period, time_off_policy.next_period]
      .find { |r| r.include?(effective_at.to_date) }
  end

  def later_balances_ids
    return nil unless time_off_policy
    time_off_policy.counter? ? find_ids_for_counter : find_ids_for_balancer
  end

  def find_ids_for_balancer
    current_or_next_period && active_balances_with_removals.blank? ||
      active_balances_with_removals.blank? && policy_end_dates_blank? ||
      next_removals_smaller_than_amount? ? all_later_ids : ids_to_removal
  end

  def next_removals_smaller_than_amount?
    return false unless active_balances_with_removals
    active_balances_with_removals.pluck(:amount).map(&:abs).sum < amount.abs
  end

  def ids_to_removal
    removals = balances.where(balance_credit_addition_id: active_balances.pluck(:id))
      .order(effective_at: :asc)
    new_amount = amount

    removals.each do |removal|
      new_amount = new_amount - removal.amount unless removal.amount.abs >= new_amount.abs
      return balances.where(effective_at: effective_at..removal.effective_at).pluck(:id)
    end
  end

  def find_ids_for_counter
    return all_later_ids if current_or_next_period || next_removal.blank?
    balances.where(effective_at: effective_at..next_removal.effective_at).pluck(:id)
  end

  def next_removal
    balances.where('policy_credit_removal = true AND effective_at > ?', effective_at)
      .order(effective_at: :asc).first
  end

  def calculate_and_set_balance
    previous = previous_balances.last
    self.balance = previous && previous.id != id ? previous.balance + amount : amount
  end

  def active_balances
    balances.where('effective_at < ? AND validity_date > ?', effective_at, effective_at)
  end

  def active_balances_with_removals
    return [] unless active_balances.present?
    balances.where(id: balances.where(balance_credit_addition_id: active_balances.pluck(:id))
      .pluck(:balance_credit_addition_id))
  end

  def all_later_ids(effective = effective_at)
    balances.where("effective_at >= ?", effective).pluck(:id)
  end

  def calculate_removal_amount(addition = balance_credit_addition)
    last_balance = previous_balances.where('amount <= ?', 0).last
    return -addition.amount unless last_balance

    positive_balances = balances.where(effective_at: addition.effective_at..now_or_effective_at,
      amount: 1..Float::INFINITY, validity_date: nil).pluck(:amount).sum

    sum = (last_balance.balance - positive_balances - active_balances.pluck(:amount).sum)
    self.amount = sum > 0 ? -sum : 0
  end

  private

  def check_if_credit_removal
    self.policy_credit_removal = true
  end

  def previous_balances
    balances.where('effective_at < ?', now_or_effective_at).order(effective_at: :asc)
  end

  def now_or_effective_at
    effective_at || Time.now
  end

  def attributes_present?
    employee.present? && time_off_category.present? && amount.present? && time_off_policy.present?
  end

  def policy_end_dates_blank?
    time_off_policy.blank? || (time_off_policy.end_day.blank? && time_off_policy.end_month.blank?)
  end

  def removal_and_balancer?
    time_off_policy && time_off_policy.policy_type == 'balancer' && policy_credit_removal
  end

  def find_effective_at
    self.effective_at = Time.now
  end

  def time_off_policy_date
    return if current_or_next_period || time_off_policy.previous_period.cover?(effective_at)
    errors.add(:effective_at, 'Must belong to current, next or previous policy.')
  end

  def validity_date_later_than_effective_at
    errors.add(:effective_at, 'Must be after start month') if effective_at.to_date > validity_date
  end
end
