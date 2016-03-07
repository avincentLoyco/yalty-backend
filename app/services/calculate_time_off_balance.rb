class CalculateTimeOffBalance
  attr_reader :time_off, :employee, :balane, :presence_policy

  def initialize(time_off)
    @time_off = time_off
    @employee = time_off.employee
    @presence_policy = employee.active_presence_policy
    @minutes = 0
  end

  def call
    return 0 if presence_policy.try(:time_entries).blank?
    calculate_minutes_from_entries
  end

  private

  def calculate_minutes_from_entries
    if time_off.start_time.to_date == time_off.end_time.to_date
      [common_entries]
    else
      [whole_entries, start_entries, end_entries]
    end.flatten.reject(&:blank?).inject(:+).to_i
  end

  def start_order
    time_off.start_time.wday.to_s.sub('0', '7').to_i
  end

  def end_order
    (start_order + (num_of_days % 7)) % 7
  end

  def num_of_days
    (time_off.end_time - time_off.start_time).to_i / 1.day
  end

  def order_numbers_in_period
    return [] unless num_of_days > 0
    days = [start_order, end_order]
    (1..7).to_a - (days.min..days.max).to_a
  end

  def presence_days_with_entries_duration
    PresenceDay.with_entries(presence_policy.id).each_with_object({}) do |day, total|
      total[day.order] = day.time_entries.pluck(:duration).sum
      total
    end
  end

  def whole_entries
    orders_with_entries_occurances.map do |k, v|
      presence_days_with_entries_duration[k] * v
    end.sum
  end

  def start_entries
    return 0 unless presence_days_with_entries_duration.include?(start_order)
    day_entries(start_order).map do |entry|
      shift_start = entry.start_time_tod > starts ? entry.start_time_tod : starts
      shift_end = entry.end_time_tod >= starts ? entry.end_time_tod : midnight
      check_shift(shift_start, shift_end, entry)
    end
  end

  def end_entries
    return 0 unless presence_days_with_entries_duration.include?(end_order)
    day_entries(end_order).map do |entry|
      shift_start = entry.start_time_tod > ends ? ends : entry.start_time_tod
      shift_end = entry.end_time_tod > ends ? ends : entry.end_time_tod
      check_shift(shift_start, shift_end, entry)
    end
  end

  def common_entries
    return 0 unless presence_days_with_entries_duration.include?(start_order)
    day_entries(start_order).map do |entry|
      shift_start = starts > entry.start_time_tod ? starts : entry.start_time_tod
      shift_end = ends < entry.end_time_tod ? ends : entry.end_time_tod
      check_shift(shift_start, shift_end, entry) if shift_start < shift_end
    end
  end

  def check_shift(shift_start, shift_end, entry)
    return 0 unless shift(shift_start, shift_end).overlaps?(entry.tod_shift)
    if shift(shift_start, shift_end).contains?(entry.tod_shift)
      entry.duration
    else
      shift(shift_start, shift_end).duration / 60
    end
  end

  def orders_occurances
    if num_of_days % 7 == 0
      ((1..7).to_a * (num_of_days / 7 - 1) + order_numbers_in_period)
    else
      ((1..7).to_a * (num_of_days / 7) + order_numbers_in_period)
    end
  end

  def orders_with_entries_occurances
    occurances = orders_occurances.each_with_object(Hash.new(0)) do |order, total|
      total[order] += 1
      total
    end
    occurances.select { |k, _v| presence_days_with_entries_duration.keys.include?(k) }
  end

  def starts
    Tod::TimeOfDay.parse(time_off.start_time.strftime('%H:%M'))
  end

  def ends
    Tod::TimeOfDay.parse(time_off.end_time.strftime('%H:%M'))
  end

  def midnight
    Tod::TimeOfDay.parse('00:00')
  end

  def shift(shift_start, shift_end)
    Tod::Shift.new(shift_start, shift_end)
  end

  def day_entries(order)
    presence_policy.presence_days.where(order: order).first.try(:time_entries)
  end
end
