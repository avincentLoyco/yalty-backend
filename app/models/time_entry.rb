class TimeEntry < ActiveRecord::Base
  belongs_to :presence_day

  validates :start_time, :end_time, :presence_day, presence: true
  validate :time_order, :time_entry_not_reserved, if: :times_parsable_and_day_present?
  validate :start_time_format, :end_time_format

  before_validation :convert_time_to_hours, if: :times_parsable?

  def end_time_after_start_time?
    end_time = Tod::TimeOfDay.parse(self.end_time)
    start_time = Tod::TimeOfDay.parse(self.start_time)

    end_time > start_time || end_time.to_s == '00:00:00'
  end

  def times_parsable?
    start_time_parsable? && end_time_parsable? && !destroyed?
  end

  def times_parsable_and_day_present?
    times_parsable? && presence_day.present?
  end

  def related_entry
    return unless end_time == '00:00:00'
    PresenceDay.where(order: presence_day.order + 1, presence_policy: presence_day.presence_policy)
      .first.time_entries.where(start_time: '00:00:00').first
  end

  private

  def time_entry_not_reserved
    presence_day.time_entries.where.not(id: id).select(&:persisted?).each do |entry|
      if start_time_covered?(entry)
        errors.add(:start_time, 'time_entries can not overlap')
      end
    end
  end

  def start_time_covered?(time_entry)
    (start_time..end_time).cover?(time_entry[:start_time]) ||
      (time_entry[:start_time]..time_entry[:end_time]).cover?(start_time)
  end

  def convert_time_to_hours
    self[:start_time] = Tod::TimeOfDay.parse(start_time)
    self[:end_time] = Tod::TimeOfDay.parse(end_time)
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

  def start_time_parsable?
    Tod::TimeOfDay.parsable?(start_time)
  end

  def end_time_parsable?
    Tod::TimeOfDay.parsable?(end_time)
  end
end
