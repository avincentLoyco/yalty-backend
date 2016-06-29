class RegisteredWorkingTime < ActiveRecord::Base
  belongs_to :employee

  validate :time_entries_smaller_than_one_day, :time_entries_does_not_overlap, :unique_time_entries,
    unless: :schedule_generated, if: :time_entries_valid?
  validate :time_entries_time_format_valid
  validate :time_entries_does_not_overlaps_with_time_off
  validates :date, uniqueness: { scope: :employee }

  scope :in_day_range, lambda { |start_date, end_date|
      where("date >= ? AND date <= ?", start_date, end_date)
  }

  DATE = '1900-01-01'.freeze

  def self.hour_as_time(entry_hour)
    "#{DATE} #{entry_hour}".to_time(:utc)
  end

  private

  def entry_start_time(time_entry)
    self.class.hour_as_time(time_entry['start_time'])
  end

  def entry_end_time(time_entry)
    self.class.hour_as_time(time_entry['end_time'])
  end

  def parsable?(time)
    Tod::TimeOfDay.parsable?(time) || time == '24:00' || time == '24:00:00'
  end

  def time_entries_valid?
    time_entries.map do |time_entry|
      parsable?(time_entry['start_time']) && parsable?(time_entry['end_time'])
    end.exclude?(false)
  end

  def time_entries_time_format_valid
    return if time_entries_valid?
    errors.add(:time_entries, 'start_time and end_time must be valid times')
  end

  def time_entries_smaller_than_one_day
    return unless time_entries.map do |time_entry|
      entry_end_time(time_entry) < entry_start_time(time_entry)
    end.include?(true)
    errors.add(:time_entries, 'time_entries can not be longer than one day')
  end

  def time_entries_does_not_overlaps_with_time_off
    return unless TimeOff.for_employee_at_date(employee_id, date).present?
    errors.add(:date, 'working time day can not overlap with existing time off')
  end

  def unique_time_entries
    return unless time_entries != time_entries.uniq
    errors.add(:time_entries, 'time_entries must be uniq')
  end

  def time_entries_does_not_overlap
    return unless time_entries.each_with_index.map do |time_entry, index|
      time_entry_start = self.class.hour_as_time(time_entry['start_time'])
      time_entry_end = self.class.hour_as_time(time_entry['end_time'])
      entry_overlap?(time_entry, time_entry_start, time_entry_end, index)
    end.flatten.include?(true)
    errors.add(:time_entries, 'time_entries can not overlap')
  end

  def entry_overlap?(time_entry, time_entry_start, time_entry_end, index)
    (time_entries - [time_entry]).drop(index).map do |later_entry|
      later_entry_start = self.class.hour_as_time(later_entry['start_time'])
      later_entry_end = self.class.hour_as_time(later_entry['end_time'])

      !((time_entry_start < later_entry_start && time_entry_end <= later_entry_start) ||
        (time_entry_end > later_entry_end && time_entry_start >= later_entry_end))
    end
  end
end
