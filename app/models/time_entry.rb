class TimeEntry < ActiveRecord::Base
  belongs_to :presence_day

  validates :start_time, :end_time, :presence_day_id, presence: true
  validate :end_time_after_start_time
  validate :time_entry_not_reserved, unless: 'presence_day.try(:time_entries).blank?'

  before_validation :convert_time_to_hours

  private

  def end_time_after_start_time
    return unless start_time && end_time
    errors.add(:end_time, 'Must be after start time') if start_time > end_time
  end

  def time_entry_not_reserved
    presence_day.try(:time_entries).each do |time_entry|
      return unless start_time_covered?(time_entry)
      errors.add(:start_time, 'time_entries can not overlap')
    end
  end

  def start_time_covered?(time_entry)
    (start_time..end_time).cover?(time_entry[:start_time]) ||
      (time_entry[:start_time]..time_entry[:end_time]).cover?(start_time)
  end

  def convert_time_to_hours
    self[:start_time] = start_time.try(:to_s, :time)
    self[:end_time] = end_time.try(:to_s, :time)
  end
end
