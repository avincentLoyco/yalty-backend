class RegisteredWorkingTime < ActiveRecord::Base
  belongs_to :employee

  validate :time_entries_smaller_than_one_day, :time_entries_does_not_overlap, :unique_time_entries,
    unless: :schedule_generated, if: [:time_entries_present?, :time_entries_valid?]
  validate :time_entries_time_format_valid, if: :time_entries_present?, unless: :schedule_generated
  validate :time_entries_does_not_overlaps_with_time_off
  validates :date, uniqueness: { scope: :employee }, on: :create

  scope :in_day_range, lambda { |start_date, end_date|
    where('date >= ? AND date <= ?', start_date, end_date)
  }

  scope :for_employee_in_day_range, lambda { |employee_id, start_date, end_date|
    in_day_range(start_date, end_date).where(employee_id: employee_id)
  }

  private

  def time_entries_present?
    time_entries.first.present?
  end

  def entry_start_time(time_entry)
    TimeEntry.hour_as_time(time_entry['start_time'])
  end

  def entry_end_time(time_entry)
    TimeEntry.hour_as_time(time_entry['end_time'])
  end

  def parsable?(time)
    Tod::TimeOfDay.parsable?(time) || time == '24:00' || time == '24:00:00'
  end

  def time_entries_valid?
    time_entries.map do |time_entry|
      time_entry.class == Hash && time_entry.keys.sort == %w(end_time start_time) &&
        parsable?(time_entry['start_time']) && parsable?(time_entry['end_time'])
    end.exclude?(false)
  end

  def time_entries_time_format_valid
    return if time_entries_valid?
    errors.add(
      :time_entries, 'time entries must be array of hashes, with start_time and end_time as times'
    )
  end

  def time_entries_smaller_than_one_day
    return unless time_entries.map do |time_entry|
      entry_end_time(time_entry) < entry_start_time(time_entry)
    end.include?(true)
    errors.add(:time_entries, 'time_entries can not be longer than one day')
  end

  def unique_time_entries
    return unless time_entries != time_entries.uniq
    errors.add(:time_entries, 'time_entries must be uniq')
  end

  def time_entries_does_not_overlap
    return unless time_entries.each_with_index.map do |time_entry, index|
      entries = (time_entries - [time_entry]).drop(index)
      entries_overlap?(entry_start_time(time_entry), entry_end_time(time_entry), entries)
    end.flatten.include?(true)
    errors.add(:time_entries, 'time_entries can not overlap')
  end

  def time_entries_does_not_overlaps_with_time_off
    time_offs_for_day = TimeOff.for_employee_at_date(employee_id, date)
    return unless time_offs_for_day.map do |time_off|
      date_in_time_off_range?(time_off) || time_off_entries_overlap?(time_off)
    end.flatten.include?(true)
    errors.add(:date, 'working time day can not overlap with existing time off')
  end

  def time_off_entries_overlap?(time_off)
    if time_off.start_time.to_date == time_off.end_time.to_date
      entries_overlap?(time_off.start_hour, time_off.end_hour)
    else
      starts = starts_at_date?(time_off) ? time_off.start_hour : TimeEntry.hour_as_time('00:00')
      ends = starts_at_date?(time_off) ? TimeEntry.midnight : time_off.end_hour
      entries_overlap?(starts, ends)
    end
  end

  def entries_overlap?(time_entry_start, time_entry_end, entries = time_entries)
    entries.map do |later_entry|
      later_entry_start = entry_start_time(later_entry)
      later_entry_end = entry_end_time(later_entry)
      TimeEntry.overlaps?(time_entry_start, time_entry_end, later_entry_start, later_entry_end)
    end
  end

  def starts_at_date?(time_off)
    time_off.start_time.to_date == date
  end

  def date_in_time_off_range?(time_off)
    ((time_off.start_time.to_date + 1.day)...time_off.end_time.to_date).cover?(date)
  end
end
