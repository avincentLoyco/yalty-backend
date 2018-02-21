class TimeOffAsTimeEntriesForRange
  attr_reader :time_off, :start_time, :end_time, :day_range, :time_off_hash, :grouped_by_employee

  def initialize(start_time, end_time, time_off, grouped_by_employee = false)
    @time_off = time_off
    @start_time = start_time_for_range(start_time)
    @end_time = end_time_for_range(end_time)
    @day_range = nil
    @time_off_hash = {}
    @grouped_by_employee = grouped_by_employee
  end

  def call
    calculate_range_size
    return prepare_single_day_hash if day_range.zero?
    grouped_by_employee ? prepare_multiple_days_hash_with_employees : prepare_multiple_days_hash
    time_off_hash
  end

  private

  def calculate_range_size
    @day_range = (start_time.to_date - end_time.to_date).to_i.abs
  end

  def start_time_for_range(start_time)
    return time_off.start_time if time_off.start_time > start_time
    start_time
  end

  def end_time_for_range(end_time)
    end_time =
      time_off.end_time < end_time ? time_off.end_time : end_time

    return end_time unless end_time.strftime("%H:%M:%S") == "00:00:00"
    end_time - 1.second
  end

  def prepare_single_day_hash(single_day_start_time = start_time, single_day_end_time = end_time)
    time_off_hashes =
      [
        {
          type: "time_off",
          name: time_off.time_off_category.name,
          start_time: single_day_start_time.strftime("%H:%M:%S"),
          end_time: day_end_time(single_day_end_time)

        }
      ]
    time_off_hashes =
      grouped_by_employee ? { @time_off.employee_id => time_off_hashes } : time_off_hashes
    { single_day_start_time.to_date.to_s => time_off_hashes }
  end

  def prepare_multiple_days_hash
    time_off_hash.merge!(prepare_single_day_hash(start_time, start_time.end_of_day))
                 .merge!(prepare_single_day_hash(end_time.beginning_of_day, end_time))

    middle_days_hash.each { |day_hash| time_off_hash.merge!(day_hash) } if day_range > 1
  end

  def prepare_multiple_days_hash_with_employees
    nested_merge_into_result_hash(prepare_single_day_hash(start_time, start_time.end_of_day))
    nested_merge_into_result_hash(prepare_single_day_hash(end_time.beginning_of_day, end_time))

    middle_days_hash.each { |day_hash| nested_merge_into_result_hash(day_hash) } if day_range > 1
  end

  def nested_merge_into_result_hash(new_time_entry)
    time_off_hash.merge!(new_time_entry) do |_key, employee_hash1, employee_hash2|
      employee_hash1.merge!(employee_hash2) do |_key, val1, val2|
        val1.push(val2.first)
      end
    end
  end

  def middle_days_hash
    (((start_time + 1.day).to_date)..((end_time - 1.day).to_date)).map do |date|
      prepare_single_day_hash(date.beginning_of_day, date.end_of_day)
    end
  end

  def day_end_time(end_time)
    end_time.strftime("%H:%M:%S") == "23:59:59" ? "24:00:00" : end_time.strftime("%H:%M:%S")
  end
end
