class CalculateTimeOffBalance
  attr_reader :time_off, :employee, :balane, :presence_policy, :time_off_start_date,
    :time_off_end_date, :holidays_dates_hash

  def initialize(time_off)
    @time_off = time_off
    @time_off_start_date = time_off.start_time
    @time_off_end_date = time_off.end_time
    @employee = time_off.employee
    @holidays_dates_hash = holidays_dates_in_time_off(time_off_holidays)
  end

  def call
    minutes_in_time_off = 0
    active_epps = active_join_table_for_time_off(EmployeePresencePolicy)
    active_epps.each do |epp|
      next if epp.presence_policy.try(:time_entries).blank?
      @epp_start_datetime =
        epp == active_epps.first ? time_off_start_date : epp.effective_at.to_datetime
      @epp_start_date = @epp_start_datetime.to_date
      @epp_end_datetime =
        epp == active_epps.last ? time_off_end_date : epp.effective_till.to_datetime + 1
      @epp_end_date = @epp_end_datetime.to_date
      @presence_policy = epp.presence_policy
      minutes_in_time_off += calculate_minutes_from_entries
    end
    minutes_in_time_off
  end

  private

  def previous_day_order(order)
    order == 1 ? @presence_policy.last_day_order : order - 1
  end

  def active_join_table_for_time_off(join_table_class)
    JoinTableWithEffectiveTill
      .new(
        join_table_class,
        employee.account_id,
        nil,
        employee.id,
        nil,
        time_off_start_date,
        time_off_end_date)
      .call
      .map do |join_table_hash|
        join_table_class.new(join_table_hash)
      end
  end

  def time_off_holidays
    all_holidays = []
    active_ewps = active_join_table_for_time_off(EmployeeWorkingPlace)
    active_ewps.each do |ewp|
      holiday_policy = ewp.working_place.holiday_policy
      next unless holiday_policy
      start_date = ewp == active_ewps.first ? time_off_start_date : ewp.effective_at.to_date
      end_date = ewp == active_ewps.last ? time_off_end_date : ewp.effective_till.to_date
      all_holidays += holiday_policy.holidays_in_period(start_date, end_date)
    end
    all_holidays
  end

  def holidays_dates_in_time_off(time_off_holidays)
    holidays_hash = { start_or_end_days: [], middle_days: [] }
    time_off_holidays.each do |holiday|
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
    if @epp_start_date == @epp_end_date
      [common_entries]
    else
      [whole_entries, start_entries, end_entries]
    end.flatten.reject(&:blank?).inject(:+).to_i
  end

  def start_order
    @epp_start_date.wday.to_s.sub('0', '7').to_i
  end

  def end_order
    (start_order + num_of_days_in_time_off - 1) % 7
  end

  def num_of_days_in_time_off
    (@epp_end_date.to_date - @epp_start_date.to_date).to_i + 1
  end

  def presence_days_with_entries_duration
    PresenceDay.with_entries(@presence_policy.id).each_with_object({}) do |day, total|
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
    return 0 unless day_order_in_period_and_not_holiday?(start_order, @epp_start_date)
    day_entries(start_order).map do |entry|
      shift_start = entry.start_time_tod > starts ? entry.start_time_tod : starts
      shift_end = entry.end_time_tod >= starts ? entry.end_time_tod : midnight
      check_shift(shift_start, shift_end, entry)
    end
  end

  def end_entries
    return 0 unless day_order_in_period_and_not_holiday?(end_order, @epp_end_date)
    day_entries(end_order).map do |entry|
      shift_start = entry.start_time_tod > ends ? ends : entry.start_time_tod
      shift_end = entry.end_time_tod > ends ? ends : entry.end_time_tod
      check_shift(shift_start, shift_end, entry)
    end
  end

  def common_entries
    return 0 unless day_order_in_period_and_not_holiday?(start_order, @epp_start_date)
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
    previous_order = previous_day_order(start_order)
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
    Tod::TimeOfDay.parse(@epp_start_datetime.strftime('%H:%M'))
  end

  def ends
    Tod::TimeOfDay.parse(@epp_end_datetime.strftime('%H:%M'))
  end

  def midnight
    Tod::TimeOfDay.parse('00:00')
  end

  def shift(shift_start, shift_end)
    Tod::Shift.new(shift_start, shift_end)
  end

  def day_entries(order)
    @presence_policy.presence_days.find_by(order: order).try(:time_entries)
  end
end
