class CalculateTimeOffBalance
  attr_reader :time_off, :employee, :balane, :time_off_policy

  def initialize(time_off)
    @time_off = time_off
    @employee = time_off.employee
    @time_off_policy = employee.active_presence_policy
    @minutes = 0
  end

  def call
    return 0 if time_off_policy.try(:time_entries).blank?
    calculate_minutes_from_entries
  end

  private

  def calculate_minutes_from_entries
    return common_entries if time_off.start_time.to_date == time_off.end_time.to_date
    whole_entries + start_entries + end_entries
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

  def occurances_with_entries
    all_orders = num_of_days % 7 == 0 ? ((1..7).to_a * (num_of_days / 7 - 1) + repeated) :
      ((1..7).to_a * (num_of_days / 7) + repeated)
    total_occurances = all_orders.inject(Hash.new(0)) { |total, e| total[e] += 1 ;total }
    total_occurances.select { |k, _v| presence_days_with_entries_duration.keys.include?(k) }
  end

  def repeated
    return [] unless num_of_days > 0
    days = [start_order, end_order]
    (1..7).to_a - (days.min..days.max).to_a
  end

  def presence_days_with_entries_duration
    PresenceDay.joins(:time_entries)
      .where('time_entries.id IS NOT NULL AND presence_policy_id = ?', time_off_policy.id)
      .inject(Hash.new(0)) { |t, e| t[e.order] = e.time_entries.pluck(:duration).sum ;t }
  end

  def whole_entries
    occurances_with_entries.map do |k, v|
      presence_days_with_entries_duration[k] * v
    end.sum
  end

  def start_entries
    return 0 unless presence_days_with_entries_duration.include?(start_order)
    day_entries(start_order).map do |entry|
      shift_start = entry.start_time_tod > starts ? entry.start_time_tod : starts
      if shift(shift_start, midnight).overlaps?(entry.tod_shift)
        shift(shift_start, midnight).contains?(entry.tod_shift) ?
          entry.duration : shift(shift_start, entry.end_time_tod).duration / 60
      end
    end.reject(&:blank?).inject(:+).to_i
  end

  def end_entries
    return 0 unless presence_days_with_entries_duration.include?(end_order)
    day_entries(end_order).map do |entry|
      shift_end = entry.end_time_tod > ends ? ends : entry.end_time_tod
      if shift(midnight, shift_end).overlaps?(entry.tod_shift)
        shift(midnight, shift_end).contains?(entry.tod_shift) ?
          entry.duration : shift(entry.start_time_tod, shift_end).duration / 60
      end
    end.reject(&:blank?).inject(:+).to_i
  end

  def common_entries
    return 0 unless presence_days_with_entries_duration.include?(start_order)
    day_entries(start_order).map do |entry|
      if shift.overlaps?(entry.tod_shift)
        if shift.contains?(entry.tod_shift)
          entry.duration
        else
          started = starts > entry.start_time_tod ? starts : entry.start_time_tod
          ended = ends < entry.end_time_tod ? ends : entry.end_time_tod
          Tod::Shift.new(started, ended).duration / 60
        end
      end
    end.reject(&:blank?).inject(:+).to_i
  end

  def starts
    Tod::TimeOfDay.parse(time_off.start_time.strftime("%H:%M"))
  end

  def ends
    Tod::TimeOfDay.parse(time_off.end_time.strftime("%H:%M"))
  end

  def midnight
    Tod::TimeOfDay.parse("00:00")
  end

  def shift(shift_start = starts, shift_end = ends)
    Tod::Shift.new(shift_start, shift_end)
  end

  def day_entries(order)
    time_off_policy.presence_days.where(order: order).first.try(:time_entries)
  end
end
