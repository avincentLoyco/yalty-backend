require 'employee_policy_period'

class Employee::Balance < ActiveRecord::Base
  belongs_to :employee
  belongs_to :time_off_category
  belongs_to :time_off
  belongs_to :employee_time_off_policy

  belongs_to :balance_credit_addition, class_name: 'Employee::Balance'
  has_one :balance_credit_removal, class_name: 'Employee::Balance',
                                   foreign_key: 'balance_credit_addition_id', dependent: :destroy

  validates :employee, :time_off_category, :balance, :effective_at, :resource_amount,
    :manual_amount, presence: true
  validates :effective_at, uniqueness: { scope: [:time_off_category, :employee] }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }, if: :validity_date
  validates :employee_time_off_policy_id, uniqueness: true, allow_nil: true
  validate :removal_effective_at_date, if: [:balance_credit_addition, :time_off_policy]
  validate :validity_date_later_than_effective_at, if: [:effective_at, :validity_date]
  validate :counter_validity_date_blank
  validate :time_off_policy_presence
  validate :effective_after_employee_start_date, if: :employee
  validate :effective_at_equal_time_off_policy_dates, if: :employee_time_off_policy_id
  validate :effective_at_equal_time_off_end_date, if: :time_off_id
  before_validation :calculate_and_set_balance, if: :attributes_present?
  before_validation :find_effective_at
  before_validation :check_if_credit_removal, if: :balance_credit_addition

  scope :employee_balances, lambda  { |employee_id, time_off_category_id|
    where(employee_id: employee_id, time_off_category_id: time_off_category_id)
  }
  scope :editable, lambda {
    where(policy_credit_removal: false, policy_credit_addition: false, time_off_id: nil)
  }
  scope :additions, -> { where(policy_credit_addition: true).order(:effective_at) }
  scope :removals, -> { where(policy_credit_removal: true).order(:effective_at) }

  def amount
    return unless resource_amount && manual_amount
    resource_amount + manual_amount
  end

  def last_in_category?
    last_balance_id = employee.last_balance_in_category(time_off_category_id).try(:id)
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
    self.resource_amount = CalculateEmployeeBalanceRemovalAmount.new(self, addition).call
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
      time_off.try(:end_time) || Time.zone.now
    end
  end

  private

  def attributes_present?
    employee.present? && time_off_category.present? && amount.present? && time_off_policy.present?
  end

  def check_if_credit_removal
    return unless balance_credit_addition.policy_credit_addition
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
    return unless time_off_policy.policy_type == 'balancer' && balance_credit_addition.validity_date
    if effective_at.to_date != balance_credit_addition.validity_date.to_date
      errors.add(:effective_at, 'Removal effective at must equal addition validity date')
    end
  end

  def validity_date_later_than_effective_at
    errors.add(:effective_at, 'Must be after start date') if effective_at > validity_date
  end

  def time_off_policy_presence
    errors.add(:employee, 'Must have time off policy in category') unless time_off_policy
  end

  def effective_after_employee_start_date
    return unless effective_at < employee.first_employee_event.effective_at
    errors.add(:effective_at, 'Can not be added before employee start date')
  end

  def effective_at_equal_time_off_policy_dates
    time_off_policy = employee_time_off_policy.time_off_policy
    etop_hash = employee_time_off_policy_with_effective_till
    etop_effective_at_year = etop_hash['effective_at'].to_date.year
    etop_effective_till_year =
      etop_hash['effective_till'] ? etop_hash['effective_till'].to_date.year : nil
    matches_end_or_start_top_date = compare_effective_at_with_time_off_polices_related_dates(
      time_off_policy,
      etop_effective_at_year,
      etop_effective_till_year
    )
    matches_effective_at = effective_at.to_date == employee_time_off_policy.effective_at.to_date
    return unless !matches_end_or_start_top_date && !matches_effective_at
    message = 'Must be at TimeOffPolicy  assignations date, end date, start date or the previous'\
      ' day to start date'
    errors.add(:effective_at, message)
  end

  def employee_time_off_policy_with_effective_till
    JoinTableWithEffectiveTill.new(
      EmployeeTimeOffPolicy,
      nil,
      employee_time_off_policy.time_off_policy_id
    ).call.first
  end

  def compare_effective_at_with_time_off_polices_related_dates(
    time_off_policy,
    etop_effective_at_year,
    etop_effective_till_year
  )
    start_day = time_off_policy.start_day
    start_month = time_off_policy.start_month
    end_day = time_off_policy.end_day
    end_month = time_off_policy.end_month
    day = effective_at.to_date.day
    month = effective_at.to_date.month
    year = effective_at.to_date.year
    previous_date = Date.new(year, start_month, start_day) - 1
    check_year = (year >= etop_effective_at_year &&
      (etop_effective_till_year.nil? || year <= etop_effective_till_year))
    check_start_day_related = (day == start_day && month == start_month) ||
      (day == previous_date.day && month == previous_date.month)
    check_end_day = (day == end_day && month == end_month)
    if end_day.present? && end_month.present?
      check_year && check_start_day_related
    else
      check_year && (check_start_day_related || check_end_day)
    end
  end

  def effective_at_equal_time_off_end_date
    return unless effective_at.to_date != time_off.end_time.to_date
    errors.add(:effective_at, "Must be at time off's end date")
  end
end
