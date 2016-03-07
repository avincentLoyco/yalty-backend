class TimeOffPolicy < ActiveRecord::Base
  belongs_to :time_off_category
  has_many :employee_balances, class_name: 'Employee::Balance'
  has_many :employee_time_off_policies
  has_many :employees, through: :employee_time_off_policies
  has_many :working_place_time_off_policies
  has_many :working_places, through: :working_place_time_off_policies
  validate :correct_dates
  validates :start_day,
    :start_month,
    :policy_type,
    :time_off_category,
    :name,
    presence: true
  validates :years_passed, numericality: { greater_than_or_equal_to: 0 }
  validates :amount, presence: true, if: "policy_type == 'balancer'"
  validates :amount, absence: true, if: "policy_type == 'counter'"
  validates :policy_type, inclusion: { in: %w(counter balancer) }
  validates :years_to_effect,
    numericality: { greater_than_or_equal_to: 0 }, if: 'years_to_effect.present?'
  validates :start_day,
    :start_month,
    numericality: { greater_than_or_equal_to: 1 }
  validates :end_day,
    :end_month,
    numericality: { greater_than_or_equal_to: 1 },
    presence: true,
    if: "(end_day.present? || end_month.present?) && policy_type == 'balancer'"
  validate :no_end_dates, if: "policy_type == 'counter'"
  validate :end_date_after_start_date, if: [:start_day, :start_month, :end_day, :end_month]

  scope :for_account_and_category, lambda { |account_id, time_off_category_id|
    joins(:time_off_category).where(
      time_off_categories: { account_id: account_id, id: time_off_category_id }
    )
  }

  def counter?
    policy_type == 'counter'
  end

  def affected_employees_ids
    (working_place_time_off_policies.affected_employees(id) +
      employee_time_off_policies.affected_employees(id)).uniq
  end

  def start_date
    Date.new(Time.zone.today.year - start_years_ago, start_month, start_day)
  end

  def end_date
    return start_date + years_or_effect unless end_day && end_month
    Date.new(end_in_years, end_month, end_day)
  end

  def current_period
    (start_date...end_date)
  end

  def previous_period
    (start_date - years_or_effect...end_date - years_or_effect)
  end

  def next_period
    (start_date + years_or_effect...end_date + years_or_effect)
  end

  def start_years_ago
    return 0 unless years_to_effect && years_to_effect > 1
    years_passed % years_to_effect
  end

  def years_or_effect
    return (years_to_effect.to_i + 1).years if years_to_effect.blank? || dates_blank?
    years_to_effect > 1 ? years_to_effect.years : 1.year
  end

  def end_in_years
    start_date.year + years_to_effect
  end

  def starts_today?
    start_date == Time.zone.today
  end

  def ends_today?
    end_date == Time.zone.today
  end

  private

  def dates_blank?
    (end_day.blank? && end_month.blank?)
  end

  def correct_dates
    verify_date(start_day, start_month, :start_day, :start_month)
    verify_date(end_day, end_month, :end_day, :end_month) if end_day.present? || end_month.present?
  end

  def verify_date(day, month, day_symbol, month_symbol)
    verify_invalid_month(month, month_symbol)
    verify_invalid_day(day, month, day_symbol)
    verify_twenty_of_february(day, month, day_symbol)
  end

  def verify_invalid_day(day, month, day_symbol)
    days_in_month = month ? Time.days_in_month(month, Time.zone.now.year) : nil
    errors.add(day_symbol, 'invalid day number given for this month') if
      day && days_in_month && day >= days_in_month
  end

  def verify_invalid_month(month, month_symbol)
    errors.add(month_symbol, 'invalid month number') unless month && month >= 1 && month <= 12
  end

  def verify_twenty_of_february(day, month, day_symbol)
    errors.add(day_symbol, '29 of February is not an allowed day') if day == 29 && month == 2
  end

  def no_end_dates
    errors.add(:end_day, 'Should be null for this type of policy') if end_day.present?
    errors.add(:end_month, 'Should be null for this type of policy') if end_month.present?
  end

  def end_date_after_start_date
    return unless errors.blank?
    errors.add(:end_month, 'Must be after start month') if end_date < start_date
  end
end
