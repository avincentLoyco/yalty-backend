class TimeOffPolicy < ActiveRecord::Base
  include ActsAsIntercomTrigger

  belongs_to :time_off_category
  has_many :employee_time_off_policies
  has_many :employees, through: :employee_time_off_policies
  validate :correct_dates, unless: :reset?
  validates :time_off_category, :name, presence: true
  validates :amount, presence: true, if: "policy_type == 'balancer'"
  validates :policy_type, presence: true, inclusion: { in: %w(counter balancer) }, unless: :reset?
  validates :years_to_effect,
    numericality: { greater_than_or_equal_to: 0 }, if: "years_to_effect.present?"
  validates :start_day,
    :start_month,
    numericality: { greater_than_or_equal_to: 1 },
    presence: true,
    unless: :reset?
  validates :end_day,
    :end_month,
    numericality: { greater_than_or_equal_to: 1 },
    presence: true,
    if: "(end_day.present? || end_month.present?) && policy_type == 'balancer'"
  validate :no_end_dates, if: "policy_type == 'counter'"
  validate :end_date_after_start_date, if: [:start_day, :start_month, :end_day, :end_month]
  validate :no_end_date_when_years_to_effect_nil, if: [:end_day, :end_month]

  scope :not_reset, -> { where(reset: false) }
  scope :reset_policies, -> { where(reset: true) }

  scope(:for_account, lambda do |account_id|
    joins(:time_off_category).where(time_off_categories: { account_id: account_id })
  end)

  scope(:for_account_and_category, lambda do |account_id, time_off_category_id|
    joins(:time_off_category).where(
      time_off_categories: { account_id: account_id, id: time_off_category_id }
    )
  end)

  scope :vacations, -> { joins(:time_off_category).merge(TimeOffCategory.vacation) }

  scope(:default_counters, lambda do
    joins(:time_off_category)
      .where(time_off_categories: { name: ["accident", "sickness", "maternity", "civil_service"] })
  end)

  scope(:not_default_counters, lambda do
    joins(:time_off_category).where
      .not(time_off_categories: { name: ["accident", "sickness", "maternity", "civil_service"] })
  end)

  scope :counters, -> { where(policy_type: "counter") }

  scope :active_balancers, -> { where(active: true, policy_type: "balancer") }

  def counter?
    policy_type == "counter"
  end

  private

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
    errors.add(day_symbol, "invalid day number given for this month") if
      day && days_in_month && day > days_in_month
  end

  def verify_invalid_month(month, month_symbol)
    errors.add(month_symbol, "invalid month number") unless month && month >= 1 && month <= 12
  end

  def verify_twenty_of_february(day, month, day_symbol)
    errors.add(day_symbol, "29 of February is not an allowed day") if day == 29 && month == 2
  end

  def no_end_date_when_years_to_effect_nil
    return unless years_to_effect.blank?
    errors.add(:end_month, "Must be empty when years to effect not given")
    errors.add(:end_day, "Must be empty when years to effect not given")
  end

  def no_end_dates
    errors.add(:end_day, "Should be null for this type of policy") if end_day.present?
    errors.add(:end_month, "Should be null for this type of policy") if end_month.present?
  end

  def end_date_after_start_date
    return unless errors.blank?
    start_date =  Date.new(Time.zone.today.year, start_month, start_day)
    end_date = Date.new(Time.zone.today.year, end_month, end_day) + years_to_effect.to_i.years
    errors.add(:end_month, "Must be after start month") if end_date <= start_date
  end
end
