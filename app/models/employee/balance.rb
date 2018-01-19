require 'employee_policy_period'

class Employee::Balance < ActiveRecord::Base
  include RelatedAmount

  END_OF_PERIOD_OFFSET = 1.second
  REMOVAL_OFFSET       = 2.seconds
  RESET_OFFSET         = 3.seconds
  ASSIGNATION_OFFSET   = 4.seconds
  ADDITION_OFFSET      = 5.seconds
  MANUAL_ADJUSTMENT    = 6.seconds

  belongs_to :employee
  belongs_to :time_off_category
  belongs_to :time_off

  has_many :balance_credit_additions, class_name: 'Employee::Balance',
                                      foreign_key: 'balance_credit_removal_id'
  belongs_to :balance_credit_removal, class_name: 'Employee::Balance'

  validates :employee, :time_off_category, :balance, :effective_at, :resource_amount,
    :manual_amount, :balance_type, presence: true
  validates :validity_date, presence: true, if: :balance_credit_removal_id
  validates :balance_type,
    inclusion: { in: %w(time_off reset removal manual_adjustment end_of_period assignation addition) }
  validates :effective_at, uniqueness: { scope: [:time_off_category, :employee] }
  validate :validity_date_later_than_effective_at, if: [:effective_at, :validity_date]
  validate :counter_validity_date_blank
  validate :time_off_policy_presence
  validate :effective_after_employee_start_date, if: :employee
  validate :effective_at_equal_time_off_policy_dates, if: 'time_off_id.nil? && employee_id'
  validate :effective_at_equal_time_off_end_date, if: :time_off_id
  validate :removal_effective_at_date
  validate :end_time_not_after_contract_end, if: [:employee, :effective_at]
  validate :reset_effective_at_after_contract_end, if: [:employee, :effective_at]

  before_validation :find_effective_at
  before_validation :calculate_amount_from_time_off, if: :time_off_id
  before_validation :calculate_and_set_balance, if: :attributes_present?

  scope :for_employee_and_category, (lambda do |employee_id, time_off_category_id|
    where(employee_id: employee_id, time_off_category_id: time_off_category_id)
  end)
  scope :between, (lambda do |from_date, to_date|
    where('employee_balances.effective_at BETWEEN ? and ?', from_date, to_date)
  end)
  scope :additions, -> { where(balance_type: 'addition').order(:effective_at) }
  scope :removals, -> { Employee::Balance.joins(:balance_credit_additions).distinct }
  scope :not_removals, (lambda do
    joins('LEFT JOIN employee_balances AS b ON employee_balances.id = b.balance_credit_removal_id')
    .distinct
    .where('b.balance_credit_removal_id IS NULL')
  end)
  scope :removal_at_date, (lambda do |employee_id, time_off_category_id, date|
    for_employee_and_category(employee_id, time_off_category_id)
      .where(balance_type: %w(reset removal)).where(effective_at: date).uniq
  end)
  scope :reset, -> { where(reset_balance: true) }

  scope :in_category, ->(category_id) { where(time_off_category_id: category_id) }
  scope :with_time_off, -> { where.not(time_off_id: nil) }
  scope :not_time_off, -> { where(time_off_id: nil) }

  def amount
    return unless resource_amount && manual_amount
    resource_amount + manual_amount + related_amount
  end

  def last_in_category?
    last_balance_id = employee.last_balance_in_category(time_off_category_id).try(:id)
    id == last_balance_id || last_balance_id.blank?
  end

  def current_or_next_period
    [EmployeePolicyPeriod.new(employee, time_off_category_id).current_policy_period,
     EmployeePolicyPeriod.new(employee, time_off_category_id).future_policy_period]
      .compact.find { |r| r.include?(effective_at.to_date) }
  end

  def calculate_and_set_balance
    previous = RelativeEmployeeBalancesFinder.new(self).previous_balances.last
    self.balance = (previous && previous.id != id ? previous.balance + amount : amount)
  end

  def calculate_removal_amount
    self.resource_amount = CalculateEmployeeBalanceRemovalAmount.new(self).call
  end

  def time_off_policy
    return nil unless employee && time_off_category
    employee_time_off_policy.try(:time_off_policy)
  end

  def now_or_effective_at
    return effective_at if effective_at && time_off.blank?
    if balance_credit_additions.present?
      balance_credit_additions.map(&:validity_date).first
    else
      time_off.try(:end_time) || Time.zone.now
    end
  end

  def employee_time_off_policy
    date =
      if balance_credit_additions.present?
        effective_at_from_additions
      else
        now_or_effective_at
      end
    employee.active_policy_in_category_at_date(time_off_category_id, date)
  end

  private

  def effective_at_from_additions
    if balance_credit_additions.map(&:balance_type).eql?(['end_of_period'])
      balance_credit_additions.first.effective_at - 1.day
    else
      balance_credit_additions.sort_by { |balance| balance[:effective_at] }.first.effective_at
    end
  end

  def end_time_not_after_contract_end
    contract_end = employee.contract_end_for(effective_at)

    return unless !balance_type.eql?('reset') && contract_end.present? &&
        contract_end > employee.hired_date_for(effective_at) &&
        (contract_end + 1.day) + Employee::Balance::REMOVAL_OFFSET < effective_at
    errors.add(:effective_at, 'Employee Balance can not be added after employee contract end date')
  end

  def reset_effective_at_after_contract_end
    return unless balance_type.eql?('reset')
    contract_end = employee.contract_end_for(effective_at)
    return if contract_end &&
        (contract_end + 1.day + Employee::Balance::RESET_OFFSET) == effective_at
    errors.add(:effective_at, 'Reset Balance effective at must be at contract end')
  end

  def attributes_present?
    employee.present? && time_off_category.present? && amount.present? && time_off_policy.present?
  end

  def find_effective_at
    self.effective_at = now_or_effective_at
  end

  def calculate_amount_from_time_off
    self.resource_amount = time_off.balance
  end

  def counter_validity_date_blank
    return unless time_off_policy.try(:counter?) && validity_date.present?
    errors.add(:validity_date, 'Must be nil when counter type')
  end

  def removal_effective_at_date
    additions_validity_dates = balance_credit_additions.map(&:validity_date).uniq

    return unless balance_type.eql?('removal') && additions_validity_dates.present?
    first_validity_date = additions_validity_dates.first.try(:to_date)

    if additions_validity_dates.size > 1 ||
        effective_at && effective_at.to_date != first_validity_date ||
        !employee.contract_periods_include?(
          effective_at.to_date - 1.day, first_validity_date - 1.day
        )
      errors.add(
        :effective_at, 'Removal effective at must equal addition validity date and period'
      )
    end
  end

  def validity_date_later_than_effective_at
    errors.add(:effective_at, 'Must be after start date') if effective_at > validity_date
  end

  def time_off_policy_presence
    return if time_off_policy && (balance_type.eql?('reset') || balance_type.eql?('time_off') ||
                                  (!balance_type.eql?('reset') && !time_off_policy.reset))
    errors.add(:employee, 'Must have an associated time off policy in the balance category')
  end

  def effective_after_employee_start_date
    return if balance_type.eql?('reset') || employee.contract_periods_include?(effective_at)

    errors.add(:effective_at, 'can\'t be set outside of employee contract period')
  end

  def effective_at_equal_time_off_policy_dates
    return if balance_type.eql?('manual_adjustment')
    etop = employee_time_off_policy
    return if etop.blank? || balance_type.eql?('reset') || !etop.not_reset?
    etop_hash = employee_time_off_policy_with_effective_till(etop)
    matches_end_or_start_top_date = compare_effective_at_with_time_off_polices_related_dates(
      time_off_policy,
      etop_hash['effective_at'].to_date,
      etop_hash['effective_till'].try(:to_date)
    )
    matches_effective_at = effective_at.to_date == etop.effective_at.to_date
    return unless !matches_end_or_start_top_date && !matches_effective_at
    message = 'Must be at TimeOffPolicy  assignations date, end date, start date or the previous'\
      ' day to start date'
    errors.add(:effective_at, message)
  end

  def employee_time_off_policy_with_effective_till(etop)
    JoinTableWithEffectiveTill.new(
      EmployeeTimeOffPolicy,
      nil,
      nil,
      nil,
      etop.id,
      nil
    ).call.first
  end

  def compare_effective_at_with_time_off_polices_related_dates(
    time_off_policy,
    etop_effective_at,
    etop_effective_till
  )
    day = now_or_effective_at.to_date.day
    month = now_or_effective_at.to_date.month
    year = now_or_effective_at.to_date.year

    valid_start_day_related =
      check_start_day_related(
        time_off_policy,
        etop_effective_at,
        etop_effective_till,
        year,
        month,
        day
      )
    valid_end_date =
      check_end_date(
        time_off_policy,
        etop_effective_at,
        etop_effective_till,
        year,
        month,
        day
      )

    valid_start_day_related || valid_end_date
  end

  def check_start_day_related(
    time_off_policy,
    etop_effective_at,
    etop_effective_till,
    year,
    month,
    day
  )
    start_day = time_off_policy.start_day
    start_month = time_off_policy.start_month
    year_in_range = year >= etop_effective_at.year &&
      (etop_effective_till.nil? || year <= etop_effective_till.year)
    correct_day_and_month = (day == start_day && month == start_month)
    year_in_range && correct_day_and_month
  end

  def check_end_date(
    time_off_policy,
    etop_effective_at,
    etop_effective_till,
    year,
    month,
    day
  )
    return false unless time_off_policy.end_month && time_off_policy.end_day
    date_in_year = Date.new(year, time_off_policy.end_month, time_off_policy.end_day) + 1.day
    end_day = date_in_year.day
    end_month = date_in_year.month
    start_day = time_off_policy.start_day
    start_month = time_off_policy.start_month

    years_to_effect = years_to_effect_for_check(
      etop_effective_till,
      end_month,
      end_day,
      start_month,
      start_day,
      time_off_policy
    )
    years_to_compare = years_to_effect.eql?(0) ? 1 : years_to_effect
    year_in_range = year >= etop_effective_at.year &&
      (etop_effective_till.nil? || year <= etop_effective_till.year + years_to_compare)
    correct_day_and_month = (day == end_day && month == end_month)
    year_in_range && correct_day_and_month
  end

  def years_to_effect_for_check(
    etop_effective_till,
    end_month,
    end_day,
    start_month,
    start_day,
    time_off_policy
  )
    return unless etop_effective_till.present?
    end_date = Date.new(etop_effective_till.year, end_month, end_day)
    start_date = Date.new(etop_effective_till.year, start_month, start_day)
    etop_effective_at = employee_time_off_policy.effective_at
    end_date_before_start_date = end_date < start_date
    end_date_after_or_equal_start_date = end_date >= start_date
    effective_till_after_or_equal_start_date = etop_effective_till >= start_date
    effective_till_before_start_date = etop_effective_till < start_date

    offset =
      if end_date_before_start_date && effective_till_after_or_equal_start_date
        time_off_policy.years_to_effect + 1
      elsif end_date_after_or_equal_start_date && effective_till_before_start_date
        time_off_policy.years_to_effect - 1
      else
        time_off_policy.years_to_effect
      end

    etop_effective_at <= end_date ? offset : offset + 1
  end

  def effective_at_equal_time_off_end_date
    return unless effective_at.to_date != time_off.end_time.to_date
    errors.add(:effective_at, "Must be at time off's end date")
  end
end
