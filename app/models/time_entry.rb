class TimeEntry < ActiveRecord::Base
  belongs_to :presence_day

  validates :start_time, :end_time, :presence_day_id, :duration, presence: true
  validates :duration, numericality: { greater_than: 0 }
  validate :time_entry_not_reserved, if: [:times_parsable?, "presence_day.present?"]
  validate :start_time_format, :end_time_format
  validate :longer_than_one_day?, if: :times_parsable?

  before_validation :convert_time_to_hours, :calculate_duration, if: :times_parsable?
  after_save :update_presence_day_minutes!

  TOD = Tod::TimeOfDay

  DATE = "1900-01-01".freeze
  START_ORDER = 1

  def start_time_as_time
    TimeEntry.hour_as_time(start_time)
  end

  def end_time_as_time
    TimeEntry.hour_as_time(end_time)
  end

  def self.midnight
    TimeEntry.hour_as_time("24:00:00")
  end

  def self.hour_as_time(entry_hour)
    "#{DATE} #{entry_hour}".to_time(:utc)
  end

  def self.overlaps?(first_start_time, first_end_time, second_start_time, second_end_time)
    !((first_start_time < second_start_time && first_end_time <= second_start_time) ||
      (first_end_time > second_end_time && first_start_time >= second_end_time))
  end

  def self.contains?(first_start_time, first_end_time, second_start_time, second_end_time)
    first_start_time <= second_start_time && first_end_time >= second_end_time
  end

  private

  def convert_time_to_hours
    self.start_time = start_time_as_time.strftime("%H:%M:%S")
    self.end_time = midnight? ? "24:00:00" : end_time_as_time.strftime("%H:%M:%S")
  end

  def update_presence_day_minutes!
    presence_day.update_minutes!
  end

  def calculate_duration
    self.duration = (TimeEntry.hour_as_time(end_time) - TimeEntry.hour_as_time(start_time)) / 60
  end

  def day_entries_overlap?
    (presence_day.try(:time_entries).to_a.select(&:persisted?) - [self]).map do |time_entry|
      TimeEntry.overlaps?(
        TimeEntry.hour_as_time(start_time),
        TimeEntry.hour_as_time(end_time),
        TimeEntry.hour_as_time(time_entry.start_time),
        TimeEntry.hour_as_time(time_entry.end_time)
      )
    end.any?
  end

  def times_parsable?
    start_time_parsable? && end_time_parsable?
  end

  def start_time_parsable?
    TOD.parsable?(start_time)
  end

  def end_time_parsable?
    midnight? || TOD.parsable?(end_time)
  end

  def midnight?
    end_time == "24:00" || end_time == "24:00:00"
  end

  def time_entry_not_reserved
    return unless day_entries_overlap?
    errors.add(:start_time, "time_entries can not overlap")
  end

  def longer_than_one_day?
    return unless start_time_as_time > end_time_as_time
    errors.add(:start_time, "time_entries can not be longer than one day")
  end

  def start_time_format
    errors.add(:start_time, "Invalid format: Time format required.") unless start_time_parsable?
  end

  def end_time_format
    errors.add(:end_time, "Invalid format: Time format required.") unless end_time_parsable?
  end
end
