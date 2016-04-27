require 'employee_policy_period'

class Employee::Balance < ActiveRecord::Base
  belongs_to :employee
  belongs_to :time_off_category
  belongs_to :time_off

  belongs_to :balance_credit_addition, class_name: 'Employee::Balance'
  has_one :balance_credit_removal, class_name: 'Employee::Balance',
                                   foreign_key: 'balance_credit_addition_id', dependent: :destroy

  validates :employee,
    :time_off_category,
    :balance, :amount,
    :effective_at,
    presence: true
  validates :effective_at, uniqueness: { scope: [:time_off_category, :employee] }
  validates :balance_credit_addition, presence: true, uniqueness: true, if: :removal_and_balancer?
  validates :amount, numericality: { greater_than_or_equal_to: 0 }, if: :validity_date
  validate :removal_effective_at_date, if: :removal_and_balancer?
  validate :validity_date_later_than_effective_at, if: [:effective_at, :validity_date]
  validate :counter_validity_date_blank
  validate :time_off_policy_presence
  validate :effective_after_employee_creation, if: :employee

  before_validation :calculate_and_set_balance, if: :attributes_present?
  before_validation :find_effective_at
  before_validation :check_if_credit_removal, if: :balance_credit_addition

  scope :employee_balances, lambda  { |employee_id, time_off_category_id|
    where(employee_id: employee_id, time_off_category_id: time_off_category_id)
  }
  scope :editable, -> { where(policy_credit_removal: false, policy_credit_addition: false) }
  scope :additions, -> { where(policy_credit_addition: true) }

  def last_in_category?
    last_balance_id =  employee.last_balance_in_category(time_off_category_id).try(:id)
    id == last_balance_id || last_balance_id.blank?
  end

  def current_or_next_period
    [EmployeePolicyPeriod.new(employee, time_off_category_id).current_policy_period,
     EmployeePolicyPeriod.new(employee, time_off_category_id).future_policy_period]
      .find { |r| r.include?(effective_at.to_date) }
  end

  def calculate_and_set_balance
    previous = RelativeEmployeeBalancesFinder.new(self).previous_balances.last
    self.balance = (previous && previous.id != id ? previous.balance + amount : amount)
  end

  def calculate_removal_amount(addition = balance_credit_addition)
    self.amount = CalculateEmployeeBalanceRemovalAmount.new(self, addition).call
  end

  def time_off_policy
    return nil unless employee && time_off_category
    employee.active_policy_in_category_at_date(time_off_category_id, now_or_effective_at)
            .try(:time_off_policy)
  end

  def now_or_effective_at
    return effective_at if effective_at && balance_credit_addition.blank? && time_off.blank?
    if balance_credit_addition.try(:validity_date)
      balance_credit_addition.validity_date
    else
      time_off.try(:start_time) || Time.zone.now
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

  def counter_validity_date_blank
    return unless time_off_policy.try(:counter?) && validity_date.present?
    errors.add(:validity_date, 'Must be nil when counter type')
  end

  def removal_effective_at_date
    return unless balance_credit_addition.validity_date.present?
    if effective_at.to_date != balance_credit_addition.validity_date.to_date
      errors.add(:effective_at, 'Removal effective at must equal addition validity date')
    end
  end

  def time_off_policy_date
    return if current_or_next_period ||
        EmployeePolicyPeriod.new(employee, time_off_category_id)
                            .previous_policy_period.cover?(effective_at)
    errors.add(:effective_at, 'Must belong to current, next or previous policy.')
  end

  def validity_date_later_than_effective_at
    errors.add(:effective_at, 'Must be after start date') if effective_at > validity_date
  end

  def time_off_policy_presence
    errors.add(:employee, 'Must have time off policy in category') unless time_off_policy
  end

  def effective_after_employee_creation
    return unless effective_at < employee.created_at
    errors.add(:effective_at, 'Can not be added before employee creation')
  end
end
