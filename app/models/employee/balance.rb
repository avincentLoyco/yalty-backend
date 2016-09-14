require 'employee_policy_period'

class Employee::Balance < ActiveRecord::Base
  belongs_to :employee
  belongs_to :time_off_category
  belongs_to :time_off

  has_many :balance_credit_additions, class_name: 'Employee::Balance',
                                      foreign_key: 'balance_credit_removal_id'
  belongs_to :balance_credit_removal, class_name: 'Employee::Balance'

  validates :employee, :time_off_category, :balance, :effective_at, :resource_amount,
    :manual_amount, presence: true
  validates :validity_date, presence: true, if: :balance_credit_removal_id
  validates :effective_at, uniqueness: { scope: [:time_off_category, :employee] }
  validate :validity_date_later_than_effective_at, if: [:effective_at, :validity_date]
  validate :counter_validity_date_blank
  validate :time_off_policy_presence
  validate :effective_after_employee_start_date, if: :employee
  validate :effective_at_equal_time_off_policy_dates, if: 'time_off_id.nil? && employee_id'
  validate :effective_at_equal_time_off_end_date, if: :time_off_id
  validate :removal_effective_at_date

  before_validation :find_effective_at
  before_validation :calculate_amount_from_time_off, if: :time_off_id
  before_validation :calculate_and_set_balance, if: :attributes_present?

  scope :employee_balances, (lambda do |employee_id, time_off_category_id|
    where(employee_id: employee_id, time_off_category_id: time_off_category_id)
  end)
  scope :additions, -> { where(policy_credit_addition: true).order(:effective_at) }
  scope :removals, -> { Employee::Balance.joins(:balance_credit_additions) }
  scope :removal_at_date, (lambda do |employee_id, time_off_category_id, date|
    employee_balances(employee_id, time_off_category_id)
      .where("effective_at::date = to_date('#{date}', 'YYYY-MM_DD')").uniq
  end)

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

  def calculate_removal_amount
    return unless balance_credit_additions.present? ||
        (policy_credit_addition && time_off_policy.counter?)
    self.resource_amount = CalculateEmployeeBalanceRemovalAmount.new(self).call
  end

  def time_off_policy
    return nil unless employee && time_off_category
    employee_time_off_policy.try(:time_off_policy)
  end

  def now_or_effective_at
    return effective_at if effective_at && balance_credit_additions.blank? && time_off.blank?
    if balance_credit_additions.present?
      balance_credit_additions.map(&:validity_date).first
    else
      time_off.try(:end_time) || Time.zone.now
    end
  end

  def employee_time_off_policy
    date =
      if balance_credit_additions.present?
        balance_credit_additions.first.effective_at
      else
        now_or_effective_at
      end
    employee.active_policy_in_category_at_date(time_off_category_id, date)
  end

  private

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
    if additions_validity_dates.present? && (additions_validity_dates.size > 1 ||
        effective_at && effective_at.to_date != additions_validity_dates.first.to_date)
      errors.add(:effective_at, 'Removal effective at must equal addition validity date')
    end
  end

  def validity_date_later_than_effective_at
    errors.add(:effective_at, 'Must be after start date') if effective_at > validity_date
  end

  def time_off_policy_presence
    return if time_off_policy
    errors.add(:employee, 'Must have an associated time off policy in the balance category')
  end

  def effective_after_employee_start_date
    return unless effective_at && effective_at < employee.hired_date
    errors.add(:effective_at, 'Can not be added before employee start date')
  end

  def effective_at_equal_time_off_policy_dates
    etop = employee_time_off_policy
    return unless etop
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
    date_before_start_day = Date.new(year, start_month, start_day) - 1
    year_in_range = year >= etop_effective_at.year &&
      (etop_effective_till.nil? || year <= etop_effective_till.year)
    correct_day_and_month = (day == start_day && month == start_month) ||
      (day == date_before_start_day.day && month == date_before_start_day.month)

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
    end_day = time_off_policy.end_day
    end_month = time_off_policy.end_month
    return false unless end_month && end_day
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

    year_in_range = year >= etop_effective_at.year &&
      (etop_effective_till.nil? || year <= etop_effective_till.year + years_to_effect)
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
    end_date_before_start_date = end_month < start_month && end_day < start_day
    end_date_after_start_date = end_month >= start_month && end_day >= start_day
    etop_effective_till_after_end_date = (etop_effective_till.month > end_month ||
      (etop_effective_till.month == end_month && (etop_effective_till.day > end_day))
    )

    if end_date_before_start_date || etop_effective_till_after_end_date
      time_off_policy.years_to_effect
    elsif end_date_after_start_date
      time_off_policy.years_to_effect - 1
    end
  end

  def effective_at_equal_time_off_end_date
    return unless effective_at.to_date != time_off.end_time.to_date
    errors.add(:effective_at, "Must be at time off's end date")
  end
end
