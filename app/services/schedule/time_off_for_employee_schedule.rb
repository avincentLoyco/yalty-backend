class TimeOffForEmployeeSchedule
  attr_reader :time_offs_in_range, :start_date, :end_date, :time_offs_hash

  def initialize(time_offs_in_range, start_date, end_date)
    @time_offs_in_range = time_offs_in_range
    @start_date = start_date
    @end_date = end_date
    @time_offs_hash = {}
  end

  def call
    return {} if time_offs_in_range.blank?
    form_time_offs_hash
    time_offs_hash
  end

  private

  def form_time_offs_hash
    time_offs_in_range.each do |time_off|
      time_offs_hash.merge!(single_time_off_hash(time_off)) do  |_key, val1, val2|
        [val1.first, val2.first]
      end
    end
  end

  def single_time_off_hash(time_off)
    start_time, end_time = calculate_time_off_for_period_range_dates(time_off)
    day_range = (start_time.to_date - end_time.to_date).to_i.abs
    category = time_off.time_off_category.name
    if day_range == 0
      prepare_single_day_hash(category, start_time, end_time)
    else
      prepare_multiple_days_hash(category, start_time, end_time, day_range)
    end
  end

  def calculate_time_off_for_period_range_dates(time_off)
    [time_off.start_time < start_date ? Time.zone.parse(start_date.to_s) : time_off.start_time,
     time_off.end_time < end_date ? time_off.end_time : Time.zone.parse(end_date.to_s)]
  end

  def prepare_single_day_hash(category, start_time, end_time)
    {
      start_time.to_date.to_s => [
        {
          type: 'time_off',
          name: category,
          start_time: start_time.strftime('%H:%M:%S'),
          end_time: end_time.strftime('%H:%M:%S')
        }
      ]
    }
  end

  def prepare_multiple_days_hash(category, start_time, end_time, day_range)
    multiple_day_hash = {}
    multiple_day_hash.merge!(prepare_single_day_hash(category, start_time, start_time.midnight))
                     .merge!(prepare_single_day_hash(category, end_time.beginning_of_day, end_time))

    if day_range > 1
      middle_days_hash(category, start_time, end_time).each do |day_hash|
        multiple_day_hash.merge!(day_hash)
      end
    end
    multiple_day_hash
  end

  def middle_days_hash(category, start_time, end_time)
    (((start_time + 1.day).to_date)..((end_time - 1.day).to_date)).map do |date|
      prepare_single_day_hash(category, date.beginning_of_day, date.midnight)
    end
  end
end
