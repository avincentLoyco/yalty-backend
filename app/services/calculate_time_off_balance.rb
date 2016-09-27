class CalculateTimeOffBalance
  attr_reader :time_off, :employee, :balane, :presence_policy, :time_off_start_date,
    :time_off_end_date, :holidays_dates_hash

  def initialize(time_off, start_time = nil, end_time = nil)
    @time_off = time_off
    @time_off_start_date = start_time || time_off.start_time
    @time_off_end_date = end_time || time_off.end_time
    @employee = time_off.employee
    @holidays_dates_hash = holidays_dates_in_time_off(time_off_holidays)
  end

  def call
    minutes_in_time_off = 0
    active_epps = active_join_table_for_time_off(EmployeePresencePolicy)
    active_epps.each do |epp|
      next if epp.presence_policy.try(:time_entries).blank?
      calculate_start_date_for_epp(epp, active_epps)
      calculate_end_date_for_epp(epp, active_epps)
      @epp = epp
      minutes_in_time_off += calculate_minutes_from_entries
    end
    minutes_in_time_off
  end

  private

  def calculate_start_date_for_epp(epp, active_epps)
    @epp_start_datetime =
      epp == active_epps.first ? time_off_start_date : epp.effective_at.to_datetime
    @epp_start_date = @epp_start_datetime.to_date
  end

  def calculate_end_date_for_epp(epp, active_epps)
    @epp_end_datetime =
      epp == active_epps.last ? time_off_end_date : epp.effective_till.to_datetime + 1
    @epp_end_date = @epp_end_datetime.to_date
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
    HolidaysForEmployeeInRange.new(employee, time_off_start_date, time_off_end_date).call
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
      holiday_day_order = @epp.order_for(holiday_date)
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
    @epp.order_for(@epp_start_date)
  end

  def end_order
    ends = (start_order + num_of_days_in_time_off - 1) % @epp.policy_length
    ends == 0 ? @epp.policy_length : ends
  end

  def num_of_days_in_time_off
    (@epp_end_date.to_date - @epp_start_date.to_date).to_i + 1
  end

  def presence_days_with_entries_duration
    PresenceDay.with_entries(@epp.presence_policy.id).each_with_object({}) do |day, total|
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
      shift_start = entry.start_time_as_time > starts ? entry.start_time_as_time : starts
      shift_end = entry.end_time_as_time >= starts ? entry.end_time_as_time : midnight
      check_shift(shift_start, shift_end, entry)
    end
  end

  def end_entries
    return 0 unless day_order_in_period_and_not_holiday?(end_order, @epp_end_date)
    day_entries(end_order).map do |entry|
      shift_start = entry.start_time_as_time > ends ? ends : entry.start_time_as_time
      shift_end = entry.end_time_as_time > ends ? ends : entry.end_time_as_time
      check_shift(shift_start, shift_end, entry)
    end
  end

  def common_entries
    return 0 unless day_order_in_period_and_not_holiday?(start_order, @epp_start_date)
    day_entries(start_order).map do |entry|
      shift_start = starts > entry.start_time_as_time ? starts : entry.start_time_as_time
      shift_end = ends < entry.end_time_as_time ? ends : entry.end_time_as_time
      check_shift(shift_start, shift_end, entry)
    end
  end

  def check_shift(shift_start, shift_end, entry)
    return 0 unless
        TimeEntry.overlaps?(
          shift_start,
          shift_end,
          entry.start_time_as_time,
          entry.end_time_as_time
        ) && shift_start < shift_end
    if TimeEntry.contains?(shift_start, shift_end, entry.start_time_as_time, entry.end_time_as_time)
      entry.duration
    else
      (shift_end - shift_start) / 60
    end
  end

  def orders_occurrences_time_off_not_longer_than_policy
    if start_order < end_order
      (start_order..end_order).to_a
    else
      (start_order..@epp.policy_length).to_a + (TimeEntry::START_ORDER..end_order).to_a
    end
  end

  def orders_occurrences_time_off_longer_than_policy
    orders_ordered_by_occurence = (start_order..@epp.policy_length).to_a
    second_period = (TimeEntry::START_ORDER..end_order).to_a
    i = 0
    week_days = (TimeEntry::START_ORDER..@epp.policy_length).to_a
    while (orders_ordered_by_occurence.size + second_period.size) < num_of_days_in_time_off
      orders_ordered_by_occurence << week_days[i % @epp.policy_length]
      i += 1
    end
    orders_ordered_by_occurence + second_period
  end

  def orders_occurances
    order_ocurrences =
      if num_of_days_in_time_off <= @epp.policy_length
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
    TimeEntry.hour_as_time(@epp_start_datetime.strftime('%H:%M:%S'))
  end

  def ends
    TimeEntry.hour_as_time(@epp_end_datetime.strftime('%H:%M:%S'))
  end

  def midnight
    TimeEntry.midnight
  end

  def day_entries(order)
    @epp.presence_policy.presence_days.find_by(order: order).try(:time_entries)
  end
end
