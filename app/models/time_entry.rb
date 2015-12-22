class TimeEntry < ActiveRecord::Base
  belongs_to :presence_day

  validates :start_time, :end_time, :presence_day, presence: true
  validate :time_order, :time_entry_not_reserved, if: :times_parsable?
  validate :start_time_format, :end_time_format

  before_validation :convert_time_to_hours, if: :times_parsable?

  def end_time_after_start_time?
    end_time = Tod::TimeOfDay.parse(self.end_time)
    start_time = Tod::TimeOfDay.parse(self.start_time)

    end_time > start_time || end_time.to_s == '00:00:00'
  end

  def times_parsable?
    start_time_parsable? && end_time_parsable?
  end

  private

  def time_entry_not_reserved
    presence_day.try(:time_entries).to_a.select(&:persisted?).each do |time_entry|
      if start_time_covered?(time_entry)
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
