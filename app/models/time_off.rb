class TimeOff < ActiveRecord::Base
  include ActsAsIntercomTrigger

  belongs_to :employee
  belongs_to :time_off_category
  has_one :employee_balance, class_name: 'Employee::Balance'

  validates :employee_id, :time_off_category_id, :start_time, :end_time, presence: true
  validate :end_time_after_start_time
  validate :time_off_policy_presence, if: 'employee.present?'
  validates :employee_balance, presence: true, on: :update
  validate :start_time_after_employee_start_date, if: [:employee, :start_time, :end_time]
  validate :does_not_overlap_with_other_users_time_offs, if: [:employee, :time_off_category_id]
  validate :does_not_overlap_with_registered_working_times, if: [:employee]
  validate :end_time_not_after_contract_end, if: [:employee, :end_time]

  scope :for_employee, ->(employee_id) { where(employee_id: employee_id) }

  scope(:for_account, lambda do |account_id|
    joins(:time_off_category)
      .where(time_off_categories: { account_id: account_id }).order(:created_at)
  end)

  scope(:vacations, lambda do
    joins(:time_off_category).where(time_off_categories: { name: 'vacation' })
  end)

  scope(:not_vacations, lambda do
    joins(:time_off_category).where.not(time_off_categories: { name: 'vacation' })
  end)

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
    for_employee(employee_id).where('? between start_time::date AND end_time::date', date)
  end)

  scope :for_employee_in_category, lambda { |employee_id, time_off_category_id|
    where(employee_id: employee_id, time_off_category_id: time_off_category_id)
  }

  scope :in_category, ->(category_id) { where(time_off_category_id: category_id) }

  def balance(starts = start_time, ends = end_time)
    - CalculateTimeOffBalance.new(self, starts, ends).call
  end

  def start_hour
    TimeEntry.hour_as_time(start_time.strftime('%H:%M'))
  end

  def end_hour
    TimeEntry.hour_as_time(end_time.strftime('%H:%M'))
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
    day_start_time = TimeEntry.hour_as_time(start_time.strftime('%H:%M:%S'))
    day_end_time = TimeEntry.hour_as_time(end_time.strftime('%H:%M:%S'))

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
        first_day_overlaps?(registered_working_time, registered_working_times.size)
      elsif registered_working_time.date == end_time.to_date
        last_day_overlaps?(registered_working_time, registered_working_times.size)
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
    errors.add(:end_time, 'Must be after start time') if start_time > end_time
  end

  def time_off_policy_presence
    active_policy = employee.active_policy_in_category_at_date(time_off_category_id, start_time)
    return unless active_policy.blank? || active_policy.time_off_policy.reset?
    errors.add(:employee, 'Time off policy in category required')
  end

  def start_time_after_employee_start_date
    return if employee.contract_periods.any? { |period| period.include?(start_time.to_date) }
    errors.add(:start_time, 'can\'t be set outside of employee contract period')
  end

  def first_day_overlaps?(registered_working_time, lenght)
    first_day_start_time = TimeEntry.hour_as_time(start_time.strftime('%H:%M:%S'))
    first_day_end_time =
      if lenght > 1
        TimeEntry.hour_as_time('24:00:00')
      else
        TimeEntry.hour_as_time(end_time.strftime('%H:%M:%S'))
      end
    overlaps_with_registered_working_time?(
      registered_working_time,
      first_day_start_time,
      first_day_end_time
    )
  end

  def last_day_overlaps?(registered_working_time, lenght)
    last_day_start_time =
      if lenght > 1
        TimeEntry.hour_as_time('00:00:00')
      else
        TimeEntry.hour_as_time(start_time.strftime('%H:%M:%S'))
      end

    last_day_end_time = TimeEntry.hour_as_time(end_time.strftime('%H:%M:%S'))
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
        TimeEntry.hour_as_time(time_entry['start_time']),
        TimeEntry.hour_as_time(time_entry['end_time'])
      )
      add_overlaping_with_working_time_errors(registered_working_time)
      break
    end
  end

  def overlaps_with_middle_days?(registered_working_time)
    return if registered_working_time.time_entries.empty?
    add_overlaping_with_working_time_errors(registered_working_time)
  end

  def add_overlaping_with_working_time_errors(registered_working_time)
    message = "Overlaps with registered working time on #{registered_working_time.date}"
    errors.add(:start_time, message)
    errors.add(:end_time, message)
  end

  def does_not_overlap_with_other_users_time_offs
    employee_time_offs_in_period =
      employee
      .time_offs
      .where(
        '(start_time >= ? AND start_time < ?) OR (end_time > ? AND end_time <= ?)',
        start_time, end_time, start_time, end_time
      )
    return if (employee_time_offs_in_period - [self]).blank?
    errors.add(:start_time, 'Time off in period already exist')
    errors.add(:end_time, 'Time off in period already exist')
  end

  def end_time_not_after_contract_end
    return if employee.contract_periods.any? do |period|
      period.include?(end_time.to_date) || end_time == (period.end + 1.day).beginning_of_day
    end
    errors.add(:end_time, 'can\'t be set outside of employee contract period')
  end
end
