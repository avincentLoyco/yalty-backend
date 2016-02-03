class Employee::Balance < ActiveRecord::Base
  belongs_to :employee
  belongs_to :time_off_category
  belongs_to :time_off
  belongs_to :time_off_policy

  belongs_to :balance_credit_addition, class_name: 'Employee::Balance'
  has_one :balance_credit_removal, class_name: 'Employee::Balance',
    foreign_key: 'balance_credit_addition_id'

  validates :employee,
    :time_off_category,
    :balance, :amount,
    :effective_at,
    :time_off_policy,
    presence: true
  validates :effective_at, uniqueness: { scope: [:time_off_policy, :employee] }
  validates :balance_credit_addition, presence: true, if: :removal_and_balancer?
  validate :time_off_policy_date, if: :time_off_policy

  before_validation :calculate_and_set_balance, if: :attributes_present?
  before_validation :set_effective_at, unless: :effective_at
  before_validation :set_validity_date, unless: [:validity_date, :policy_end_dates_blank?]

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

  def removal_and_balancer?
    time_off_policy.policy_type == 'balancer' && policy_credit_removal
  end

  def next_balance
    time_off_policy.employee_balances.where('effective_at > ? AND employee_id = ?',
      now_or_effective_at, self.employee_id).order(effective_at: :asc).first.try(:id)
  end

  def current_or_next_period?
    time_off_policy.current_period.cover?(effective_at) ||
      time_off_policy.next_period.cover?(effective_at)
  end

  def later_balances_ids
    return nil unless time_off_policy
    time_off_policy.counter? ? find_ids_for_counter : find_ids_for_balancer
  end

  def find_ids_for_balancer
    current_or_next_period? || last_removal_smaller_than_amount? ?
    all_later_ids : check_removal_and_return_ids
  end

  def find_ids_for_counter
    all_later_ids if current_or_next_period? || next_removal.blank?
    balances.where(effective_at: effective_at..next_removal.effective_at).pluck(:id)
  end

  def next_removal
    balances.order(effective_at: :asc).where(policy_credit_removal: true).first
  end

  def last_removal_smaller_than_amount?
    removals_since_effective_at.blank? || amount > last_removal.amount
  end

  def calculate_and_set_balance
    previous = previous_balance
    self.balance = previous && previous.id != id ? previous.balance + amount : amount
  end

  private

  def check_removal_and_return_ids
    ids = removals_since_effective_at.each do |removal|
      if removal.amount >= amount
        return self.class.where('effective_at > ? AND effective_at < ? AND employee_id = ?',
          self.effective_at, removal.effectve_at, employee_id).pluck(:id)
      end
    end
    ids.present? ? ids : all_later_ids
  end

  def removals_since_effective_at
    self.class.where('policy_credit_removal = true AND effective_at > ? AND employee_id = ?',
      self.effective_at, employee_id).order(effective_at: :asc)
  end

  def all_later_ids
    time_off_policy.employee_balances.where("effective_at >= ? AND employee_id = ?",
      self.effective_at, self.employee_id).pluck(:id)
  end

  def previous_balance
    time_off_policy.employee_balances.where('effective_at < ? AND employee_id = ?',
      now_or_effective_at, self.employee_id).order(effective_at: :asc).last
  end

  def now_or_effective_at
    effective_at || Time.now
  end

  def attributes_present?
    employee.present? && time_off_category.present? && amount.present? && time_off_policy.present?
  end

  def policy_end_dates_blank?
    return true unless time_off_policy
    time_off_policy.end_day.blank? && time_off_policy.end_month.blank?
  end

  def policy_period_end_date
    [time_off_policy.previous_period, time_off_policy.current_period, time_off_policy.next_period]
      .find { |r| r.include?(effective_at.to_date) }.try(:max)
  end

  def set_validity_date
    self.validity_date = policy_period_end_date
  end

  def set_effective_at
    self.effective_at = Time.now
  end

  def time_off_policy_date
    return if current_or_next_period? || time_off_policy.previous_period.cover?(effective_at)
    errors.add(:effective_at, 'Must belong to current, next or previous policy.')
  end
end
