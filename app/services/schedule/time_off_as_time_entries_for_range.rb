class TimeOffAsTimeEntriesForRange
  attr_reader :time_off, :start_time, :end_time, :day_range, :time_off_hash

  def initialize(range_start_date, range_end_date, time_off)
    @time_off = time_off
    @start_time = start_time_for_range(range_start_date)
    @end_time = end_time_for_range(range_end_date)
    @day_range = nil
    @time_off_hash = {}
  end

  def call
    calculate_range_size
    return prepare_single_day_hash if day_range == 0
    prepare_multiple_days_hash
    time_off_hash
  end

  private

  def calculate_range_size
    @day_range = (start_time.to_date - end_time.to_date).to_i.abs
  end

  def start_time_for_range(range_start_date)
    return time_off.start_time if time_off.start_time > range_start_date
    Time.zone.parse(range_start_date.to_s)
  end

  def end_time_for_range(range_end_date)
    end_time =
      time_off.end_time < range_end_date ? time_off.end_time : Time.zone.parse(range_end_date.to_s)

    return end_time unless end_time.strftime('%H:%M:%S') == '00:00:00'
    end_time - 1.second
  end

  def prepare_single_day_hash(single_day_start_time = start_time, single_day_end_time = end_time)
    {
      single_day_start_time.to_date.to_s => [
        {
          type: 'time_off',
          name: time_off.time_off_category.name,
          start_time: single_day_start_time.strftime('%H:%M:%S'),
          end_time: single_day_end_time.strftime('%H:%M:%S')
        }
      ]
    }
  end

  def prepare_multiple_days_hash
    time_off_hash.merge!(prepare_single_day_hash(start_time, start_time.end_of_day))
                 .merge!(prepare_single_day_hash(end_time.beginning_of_day, end_time))

    middle_days_hash.each { |day_hash| time_off_hash.merge!(day_hash) } if day_range > 1
  end

  def middle_days_hash
    (((start_time + 1.day).to_date)..((end_time - 1.day).to_date)).map do |date|
      prepare_single_day_hash(date.beginning_of_day, date.end_of_day)
    end
  end
end
