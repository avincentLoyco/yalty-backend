class TimeEntry < ActiveRecord::Base
  belongs_to :presence_day

  validates :start_time, :end_time, :presence_day, presence: true
  validate :time_order, :time_entry_not_reserved, :not_related_when_last,
    if: :times_parsable_and_day_present?
  validate :start_time_format, :end_time_format

  before_validation :convert_time_to_hours, if: :times_parsable?

  scope :start_at_midnight, -> { find_by(start_time: '00:00:00') }
  after_save :update_presence_day_minutes!

  TOD = Tod::TimeOfDay
  TODS = Tod::Shift

  def duration
    TODS.new(TOD.parse(start_time), TOD.parse(end_time)).duration / 60
  end

  def last_day?
    presence_day.order == presence_day.presence_policy.presence_days.pluck(:order).max
  end

  def end_time_after_start_time?
    end_time = TOD.parse(self.end_time)
    start_time = TOD.parse(self.start_time)

    end_time > start_time || end_time.to_s == '00:00:00'
  end

  def times_parsable?
    start_time_parsable? && end_time_parsable? && !destroyed?
  end

  def related_entry
    return unless end_time == '00:00:00'
    PresenceDay.related(presence_day.presence_policy, presence_day.order)
      .try(:time_entries).try(:start_at_midnight)
  end

  private

  def update_presence_day_minutes!
    presence_day.update_minutes!
  end

  def start_time_parsable?
    TOD.parsable?(start_time)
  end

  def end_time_parsable?
    TOD.parsable?(end_time)
  end

  def times_parsable_and_day_present?
    times_parsable? && presence_day.present?
  end

  def start_time_covered?(time_entry)
    new_entry = TODS.new(TOD.parse(start_time), TOD.parse(end_time), true)
    old_entry = TODS.new(TOD.parse(time_entry[:start_time]), TOD.parse(time_entry[:end_time]), true)
    new_entry.overlaps?(old_entry)
  end

  def convert_time_to_hours
    self[:start_time] = TOD.parse(start_time)
    self[:end_time] = TOD.parse(end_time)
  end

  def not_related_when_last
    return unless !end_time_after_start_time? && last_day?
    errors.add(:end_time, 'Last presence policy entry must finish at or before 00:00')
  end

  def time_entry_not_reserved
    presence_day.time_entries.where.not(id: id).select(&:persisted?).each do |entry|
      if start_time_covered?(entry)
        errors.add(:start_time, 'time_entries can not overlap')
      end
    end
  end

  def start_time_format
    errors.add(:start_time, 'Invalid format: Time format required.') unless start_time_parsable?
  end

  def end_time_format
    errors.add(:end_time, 'Invalid format: Time format required.') unless end_time_parsable?
  end

  def time_order
    errors.add(:end_time, 'Must be after start time') unless end_time_after_start_time?
  end
end
