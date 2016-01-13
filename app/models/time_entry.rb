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
    TODS.new(TOD.parse(start_time), TOD.parse(end_time)).duration / 60
  end

  def times_parsable?
    start_time_parsable? && end_time_parsable?
  end

  def related_entry
    return unless end_time == '00:00:00'
    PresenceDay.related(presence_day.presence_policy, presence_day.order)
      .try(:time_entries).try(:start_at_midnight)
  end

  private

  def time_entry_not_reserved
    return unless related_entries_overlap? || day_entries_overlap?
    errors.add(:start_time, 'time_entries can not overlap')
  end

  def day_entries_overlap?
    presence_day.try(:time_entries).to_a.select(&:persisted?).map do |time_entry|
      entry_covered?(time_entry)
    end.any?
  end

  def related_entries_overlap?
    entry_covered?(previous_entry) || entry_covered?(next_entry)
  end

  def entry_covered?(time_entry)
    return unless time_entry
    new_entry = TODS.new(TOD.parse(start_time), TOD.parse(end_time))
    existing_entry = TODS.new(TOD.parse(time_entry[:start_time]), TOD.parse(time_entry[:end_time]))

    new_entry.overlaps?(existing_entry)
  end

  def previous_entry
    presence_day.previous_day.try(:last_day_entry)
  end

  def next_entry
    presence_day.next_day.try(:first_day_entry)
  end

  def convert_time_to_hours
    self[:start_time] = TOD.parse(start_time)
    self[:end_time] = TOD.parse(end_time)
  end

  def not_related_when_last
    return unless !end_time_after_start_time? && last_day?
    errors.add(:end_time, 'Last presence policy entry must finish at or before 00:00')
  end

  def start_time_format
    errors.add(:start_time, 'Invalid format: Time format required.') unless start_time_parsable?
  end

  def end_time_format
    errors.add(:end_time, 'Invalid format: Time format required.') unless end_time_parsable?
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
end
