class Employee::Balance < ActiveRecord::Base
  include RelativeEmployeeBalancesFinders
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
  validates :balance_credit_addition, presence: true, uniqueness: true, if: :removal_and_balancer?
  validates :amount, numericality: { greater_than_or_equal_to: 0 }, if: :validity_date

  validate :removal_effective_at_date, if: :removal_and_balancer?
  validate :time_off_policy_date, if: :time_off_policy
  validate :validity_date_later_than_effective_at, if: [:effective_at, :validity_date]

  before_validation :calculate_and_set_balance, if: :attributes_present?
  before_validation :find_effective_at
  before_validation :check_if_credit_removal, if: :balance_credit_addition

  scope :employee_balances, -> (employee_id, time_off_policy_id) {
    where(employee_id: employee_id, time_off_policy: time_off_policy_id) }

  def last_in_category?
    id == employee.last_balance_in_category(time_off_category_id).id
  end

  def last_in_policy?
    id == employee.last_balance_in_policy(time_off_policy_id).id
  end

  def current_or_next_period
    [time_off_policy.current_period, time_off_policy.next_period]
      .find { |r| r.include?(effective_at.to_date) }
  end

  def calculate_and_set_balance
    previous = previous_balances.last
    self.balance = previous && previous.id != id ? previous.balance + amount : amount
  end

  def calculate_removal_amount(addition = balance_credit_addition)
    if last_balance(addition).blank?
      self.amount = addition.amount > addition.balance && addition.balance > 0 ?
        -addition.balance : -addition.amount
    else
      sum = addition.amount - previous_balances.last.try(:balance).to_i +
        + positive_balances(addition)  + active_balances.pluck(:amount).sum

      self.amount = (sum > 0 && sum < addition.amount) ? - (addition.amount - sum) : 0
    end
  end

  private

  def attributes_present?
    employee.present? && time_off_category.present? && amount.present? && time_off_policy.present?
  end

  def policy_end_dates_blank?
    time_off_policy.blank? || (time_off_policy.end_day.blank? && time_off_policy.end_month.blank?)
  end

  def removal_and_balancer?
    time_off_policy && time_off_policy.policy_type == 'balancer' && policy_credit_removal
  end

  def check_if_credit_removal
    self.policy_credit_removal = true
  end

  def find_effective_at
    self.effective_at = now_or_effective_at
  end

  def removal_effective_at_date
    return unless balance_credit_addition.validity_date.present?
    if effective_at.to_date != balance_credit_addition.validity_date.to_date
      errors.add(:effective_at, 'Removal effective at must equal addition validity date')
    end
  end

  def time_off_policy_date
    return if current_or_next_period || time_off_policy.previous_period.cover?(effective_at)
    errors.add(:effective_at, 'Must belong to current, next or previous policy.')
  end

  def validity_date_later_than_effective_at
    errors.add(:effective_at, 'Must be after start month') if effective_at > validity_date
  end
end
