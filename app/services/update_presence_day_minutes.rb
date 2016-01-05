class UpdatePresenceDayMinutes
  attr_reader :presence_days

  def initialize(presence_days)
    @presence_days = presence_days.reject(&:blank?)
  end

  def call
    presence_days.each do |presence_day|
      presence_day.update(minutes: time_entries_duration(presence_day))
    end
  end

  private

  def time_entries_duration(presence_day)
    return 0 unless presence_day.time_entries.present?
    presence_day.time_entries.map do |time_entry|
      Tod::Shift.new(
        Tod::TimeOfDay.parse(time_entry.start_time.to_i),
        Tod::TimeOfDay.parse(time_entry.end_time.to_i)
      ).duration / 60
    end.sum
  end
end
