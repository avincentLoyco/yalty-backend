class CalculateTimeOffBalance
  attr_reader :time_off, :employee, :balane, :presence_policy, :time_off_start_date,
    :time_off_end_date, :holidays, :holidays_dates_hash

  def initialize(time_off)
    @time_off = time_off
    @time_off_start_date = time_off.start_time.to_date
    @time_off_end_date = time_off.end_time.to_date
    @employee = time_off.employee
    @presence_policy = employee.active_presence_policy
    @holidays = time_off_holidays
    @holidays_dates_hash = holidays_dates_in_time_off
    @minutes = 0
  end

  def call
    return 0 if presence_policy.try(:time_entries).blank?
    calculate_minutes_from_entries
  end

  private

  def previous_day_order(order, presence_policy)
    order == 1 ? presence_policy.last_day_order : order - 1
  end

  def time_off_holidays
    # TODO, since we have effective at  needs to handle multiple holiday poliices in one time off
    #       periods (only when employee does not have directly assigned holiday policy)
    return [] unless employee.active_holiday_policy_at(time_off_start_date)
    employee
      .active_holiday_policy_at(time_off_start_date)
      .holidays_in_period(time_off_start_date, time_off_end_date)
  end

  def holidays_dates_in_time_off
    holidays_hash = { start_or_end_days: [], middle_days: [] }
    holidays.each do |holiday|
      if holiday.date == time_off_start_date || holiday.date == time_off_end_date
        holidays_hash[:start_or_end_days] << holiday.date
      else
        holidays_hash[:middle_days] << holiday.date
      end
    end
    holidays_hash
  end

  def middle_holidays_order_number
    oder_hash_counter = Hash.new(0)
    holidays_dates_hash[:middle_days].each do |holiday_date|
      holiday_day_order = holiday_date.wday.to_s.sub('0', '7').to_i
      oder_hash_counter[holiday_day_order.to_s] += 1
    end
    oder_hash_counter
  end

  def calculate_minutes_from_entries
    if time_off_start_date == time_off_end_date
      [common_entries]
    else
      [whole_entries, start_entries, end_entries]
    end.flatten.reject(&:blank?).inject(:+).to_i
  end

  def start_order
    time_off.start_time.wday.to_s.sub('0', '7').to_i
  end

  def end_order
    (start_order + num_of_days_in_time_off - 1) % 7
  end

  def num_of_days_in_time_off
    (time_off.end_time.to_date - time_off.start_time.to_date).to_i + 1
  end

  def presence_days_with_entries_duration
    PresenceDay.with_entries(presence_policy.id).each_with_object({}) do |day, total|
      total[day.order] = day.time_entries.pluck(:duration).sum
      total
    end
  end

  def whole_entries
    holidays_order_numbers = middle_holidays_order_number
    orders_with_entries_occurances.map do |k, v|
      holiday_count_with_order =
        holidays_order_numbers.key?(k.to_s) ? holidays_order_numbers[k.to_s] : 0
      presence_days_with_entries_duration[k] * (v - holiday_count_with_order)
    end.sum
  end

  def start_entries
    return 0 unless day_order_in_period_and_not_holiday?(start_order, time_off_start_date)
    day_entries(start_order).map do |entry|
      shift_start = entry.start_time_tod > starts ? entry.start_time_tod : starts
      shift_end = entry.end_time_tod >= starts ? entry.end_time_tod : midnight
      check_shift(shift_start, shift_end, entry)
    end
  end

  def end_entries
    return 0 unless day_order_in_period_and_not_holiday?(end_order, time_off_end_date)
    day_entries(end_order).map do |entry|
      shift_start = entry.start_time_tod > ends ? ends : entry.start_time_tod
      shift_end = entry.end_time_tod > ends ? ends : entry.end_time_tod
      check_shift(shift_start, shift_end, entry)
    end
  end

  def common_entries
    return 0 unless day_order_in_period_and_not_holiday?(start_order, time_off_start_date)
    day_entries(start_order).map do |entry|
      shift_start = starts > entry.start_time_tod ? starts : entry.start_time_tod
      shift_end = ends < entry.end_time_tod ? ends : entry.end_time_tod
      check_shift(shift_start, shift_end, entry)
    end
  end

  def check_shift(shift_start, shift_end, entry)
    return 0 unless shift(shift_start, shift_end).overlaps?(entry.tod_shift) &&
        shift_start < shift_end
    if shift(shift_start, shift_end).contains?(entry.tod_shift)
      entry.duration
    else
      shift(shift_start, shift_end).duration / 60
    end
  end

  def orders_occurrences_time_off_not_longer_than_policy
    if start_order < end_order
      (start_order..end_order).to_a
    else
      (start_order..7).to_a + (1..end_order).to_a
    end
  end

  def orders_occurrences_time_off_longer_than_policy
    previous_order = previous_day_order(start_order, presence_policy)
    orders_ordered_by_occurence = (start_order..7).to_a + (1..previous_order).to_a
    i = 0
    while orders_ordered_by_occurence.size < num_of_days_in_time_off
      orders_ordered_by_occurence << orders_ordered_by_occurence[i]
      i += 1
    end
    orders_ordered_by_occurence
  end

  def orders_occurances
    order_ocurrences =
      if num_of_days_in_time_off <= 7
        orders_occurrences_time_off_not_longer_than_policy
      else
        orders_occurrences_time_off_longer_than_policy
      end
    order_ocurrences.delete_at(0)
    order_ocurrences.delete_at(order_ocurrences.size - 1)
    order_ocurrences
  end

  def day_order_in_period_and_not_holiday?(order_day, day_date)
    presence_days_with_entries_duration.include?(order_day) &&
      !holidays_dates_hash[:start_or_end_days].include?(day_date)
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
    presence_policy.presence_days.find_by(order: order).try(:time_entries)
  end
end
