class TimeOff < ActiveRecord::Base
  include ActsAsIntercomTrigger
  include AASM

  belongs_to :employee
  belongs_to :time_off_category
  has_one :employee_balance, class_name: "Employee::Balance"

  delegate :auto_approved?, to: :time_off_category

  delegate :manager, :user, to: :employee, allow_nil: true

  validates :employee_id, :time_off_category_id, :start_time, :end_time, presence: true
  validate :end_time_after_start_time
  validate :time_off_policy_presence, if: "employee.present?"
  validate :does_not_overlap_with_other_users_time_offs, if: [:employee, :time_off_category_id]
  validate :does_not_overlap_with_registered_working_times, if: [:employee]
  validate :start_and_end_time_in_employee_periods, if: [:employee, :end_time, :start_time]

  scope :for_employee, ->(employee_id) { where(employee_id: employee_id) }

  scope(:for_account, lambda do |account_id|
    joins(:time_off_category)
      .where(time_off_categories: { account_id: account_id }).order(:created_at)
  end)

  scope(:vacations, lambda do
    joins(:time_off_category).where(time_off_categories: { name: "vacation" })
  end)

  scope(:not_vacations, lambda do
    joins(:time_off_category).where.not(time_off_categories: { name: "vacation" })
  end)

  scope :not_declined, -> { where.not(approval_status: TimeOff.approval_statuses.fetch(:declined)) }

  scope(:for_employee_in_period, lambda do |employee_id, start_date, end_date|
    for_employee(employee_id)
      .where(
        '((start_time::date BETWEEN ? AND ?) OR
        (end_time::date BETWEEN ? AND ?) OR
        (end_time::date > ? AND start_time::date < ?))',
        start_date, end_date, start_date, end_date, end_date, start_date
      )
      .order(:start_time)
  end)

  scope(:for_employee_at_date, lambda do |employee_id, date|
    for_employee(employee_id).where("? between start_time::date AND end_time::date", date)
  end)

  scope :for_employee_in_category, lambda { |employee_id, time_off_category_id|
    where(employee_id: employee_id, time_off_category_id: time_off_category_id)
  }

  scope :at_date, lambda { |contract_end_date|
    where("start_time <= ? AND end_time > ?",
      contract_end_date.end_of_day, contract_end_date.beginning_of_day + 1.day)
  }

  scope :in_category, ->(category_id) { where(time_off_category_id: category_id) }

  enum approval_status: { pending: 0, approved: 1, declined: 2 }

  aasm :approval_status, enum: true, no_direct_assignment: true, skip_validation_on_save: true do
    state :pending, initial: true
    state :declined, :approved

    event :approve do
      transitions from: [:pending, :declined], to: :approved
    end

    event :decline do
      transitions from: [:approved, :pending], to: :declined
    end
  end

  def balance(starts = start_time, ends = end_time)
    return 0 unless approved?
    - CalculateTimeOffBalance.new(self, starts, ends).call
  end

  def start_hour
    TimeEntry.hour_as_time(start_time.strftime("%H:%M"))
  end

  def end_hour
    TimeEntry.hour_as_time(end_time.strftime("%H:%M"))
  end

  def employee_time_off_policy
    employee.active_policy_in_category_at_date(time_off_category_id, start_time)
  end

  private

  def does_not_overlap_with_registered_working_times
    registered_working_times =
      employee.registered_working_times.in_day_range(start_time.to_date, end_time.to_date)
    if lenght > 1
      overlap_check_for_longer_than_one_day_time_off(registered_working_times)
    else
      overlap_check_for_one_day_time_off(registered_working_times)
    end
  end

  def overlap_check_for_one_day_time_off(registered_working_times)
    day_start_time = TimeEntry.hour_as_time(start_time.strftime("%H:%M:%S"))
    day_end_time = TimeEntry.hour_as_time(end_time.strftime("%H:%M:%S"))

    registered_working_times.each do |registered_working_time|
      overlaps_with_registered_working_time?(
        registered_working_time,
        day_start_time,
        day_end_time
      )
    end
  end

  def overlap_check_for_longer_than_one_day_time_off(registered_working_times)
    registered_working_times.each do |registered_working_time|
      if registered_working_time.date == start_time.to_date
        first_day_overlaps?(registered_working_time)
      elsif registered_working_time.date == end_time.to_date
        last_day_overlaps?(registered_working_time)
      else
        overlaps_with_middle_days?(registered_working_time)
      end
    end
  end

  def lenght
    (end_time.to_date - start_time.to_date).to_i + 1
  end

  def end_time_after_start_time
    return unless start_time && end_time
    errors.add(:end_time, "Must be after start time") if start_time > end_time
  end

  def time_off_policy_presence
    active_policy = employee.active_policy_in_category_at_date(time_off_category_id, start_time)
    return unless active_policy.blank? || active_policy.time_off_policy.reset?
    errors.add(:employee, "Time off policy in category required")
  end

  def first_day_overlaps?(registered_working_time)
    first_day_start_time = TimeEntry.hour_as_time(start_time.strftime("%H:%M:%S"))
    first_day_end_time = TimeEntry.hour_as_time("24:00:00")
    overlaps_with_registered_working_time?(
      registered_working_time,
      first_day_start_time,
      first_day_end_time
    )
  end

  def last_day_overlaps?(registered_working_time)
    last_day_start_time = TimeEntry.hour_as_time("00:00:00")
    last_day_end_time = TimeEntry.hour_as_time(end_time.strftime("%H:%M:%S"))
    overlaps_with_registered_working_time?(
      registered_working_time,
      last_day_start_time,
      last_day_end_time
    )
  end

  def overlaps_with_registered_working_time?(registered_working_time, to_start_time, to_end_time)
    registered_working_time.time_entries.each do |time_entry|
      next unless
      TimeEntry.overlaps?(
        to_start_time,
        to_end_time,
        TimeEntry.hour_as_time(time_entry["start_time"]),
        TimeEntry.hour_as_time(time_entry["end_time"])
      )
      add_overlaping_with_working_time_errors
      break
    end
  end

  def overlaps_with_middle_days?(registered_working_time)
    return if registered_working_time.time_entries.empty?
    add_overlaping_with_working_time_errors
  end

  def add_overlaping_with_working_time_errors
    message = "Overlaps with registered working time"
    errors.add(:start_time, message)
    errors.add(:end_time, message)
  end

  def does_not_overlap_with_other_users_time_offs
    employee_time_offs_in_period =
      employee
      .time_offs
      .not_declined
      .where(
        '((start_time >= ? AND start_time < ?) OR (end_time > ? AND end_time <= ?))
         OR (start_time <= ? AND end_time >= ?)',
        start_time, end_time, start_time, end_time, start_time, end_time
      )
    return if (employee_time_offs_in_period - [self]).blank?
    errors.add(:start_time, "Time off in period already exist")
    errors.add(:end_time, "Time off in period already exist")
  end

  def start_and_end_time_in_employee_periods
    return if employee.contract_periods_include?(end_time, start_time)
    errors.add(:end_time, "can't be set outside of employee contract period")
    errors.add(:start_time, "can't be set outside of employee contract period")
  end
end
