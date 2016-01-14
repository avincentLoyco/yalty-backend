class TimeEntry < ActiveRecord::Base
  belongs_to :presence_day

  validates :start_time, :end_time, :presence_day_id, presence: true
  validate :time_entry_not_reserved, if: :times_parsable? && :presence_day
  validate :start_time_format, :end_time_format

  before_validation :convert_time_to_hours, if: :times_parsable?
  after_save :update_presence_day_minutes!

  TOD = Tod::TimeOfDay
  TODS = Tod::Shift

  def duration
    TODS.new(start_time_tod, end_time_tod).duration / 60
  end

  def tod_shift
    TODS.new(start_time_tod, end_time_tod, true)
  end

  def ends_next_day?
    start_time_tod > end_time_tod
  end

  private

  def times_parsable?
    start_time_parsable? && end_time_parsable?
  end

  def start_time_tod
    TOD.parse(start_time)
  end

  def end_time_tod
    TOD.parse(end_time)
  end

  def day_entries_overlap?
    presence_day.try(:time_entries).to_a.select(&:persisted?).map do |time_entry|
      tod_shift.overlaps?(time_entry.tod_shift)
    end.any?
  end

  def overlaps_with_next?
    next_entry && ends_next_day? && split_entry(tod_shift).overlaps?(next_entry.tod_shift)
  end

  def overlaps_with_previous?
    previous_entry.try(:ends_next_day?) &&
      split_entry(previous_entry.tod_shift).overlaps?(tod_shift)
  end

  def previous_entry
    presence_day.previous_day.try(:last_day_entry)
  end

  def next_entry
    presence_day.next_day.try(:first_day_entry)
  end

  def start_time_parsable?
    TOD.parsable?(start_time)
  end

  def end_time_parsable?
    TOD.parsable?(end_time)
  end

  def update_presence_day_minutes!
    presence_day.update_minutes!
  end

  def convert_time_to_hours
    self.start_time = start_time_tod
    self.end_time = end_time_tod
  end

  def time_entry_not_reserved
    return unless overlaps_with_previous? || day_entries_overlap? || overlaps_with_next?
    errors.add(:start_time, 'time_entries can not overlap')
  end

  def start_time_format
    errors.add(:start_time, 'Invalid format: Time format required.') unless start_time_parsable?
  end

  def end_time_format
    errors.add(:end_time, 'Invalid format: Time format required.') unless end_time_parsable?
  end

  def split_entry(entry)
    if entry.beginning > entry.ending
      TODS.new(TOD.new(0), entry.ending, true)
    else
      entry
    end
  end
end
