class ScheduleForEmployee
  DATE = '1900-01-01'.freeze

  def initialize(employee, start_date, end_date)
    @employee = employee
    @start_date = start_date
    @end_date = end_date
    @calculated_schedule = []
  end

  def call
    create_schedule_response_structure
    populate_schedule_response
    @calculated_schedule
  end

  private

  def create_schedule_response_structure
    calculate_time_range(@start_date, @end_date).times do |i|
      date = (@start_date + i.days)
      day_hash =
        {
          date: date.to_s,
          time_entries: []
        }
      @calculated_schedule << day_hash
    end
  end

  def calculate_time_range(start_date, end_date)
    (end_date - start_date).to_i + 1
  end

  def populate_schedule_response
    @holidays_in_range = HolidaysForEmployeeSchedule.new(@employee, @start_date, @end_date).call
    @time_off_in_range = TimeOffForEmployeeSchedule.new(@employee, @start_date, @end_date).call
    @time_entries_in_range = TimeEntriesForEmployeeSchedule.new(@employee, @start_date, @end_date).call

    @calculated_schedule.each do |day_hash|
      day_hash[:time_entries] = @holidays_in_range[day_hash[:date]]
      next unless day_hash[:time_entries].empty?

      day_hash[:time_entries] = @time_off_in_range[day_hash[:date]]

      if day_hash[:time_entries].empty?
        day_hash[:time_entries] = @time_entries_in_range[day_hash[:date]]
      else
        day_hash[:time_entries] +=
          format_time_entries(
            time_entries_not_overlapped_by_time_offs(day_hash[:date])
          )
      end
    end
  end

  def time_entries_not_overlapped_by_time_offs(date)
    not_overlapped_time_entries = []
    @time_entries_in_range[date].each do |time_entry|
      start_time = "#{DATE} #{time_entry[:start_time]}".to_time(:utc)
      end_time = "#{DATE} #{time_entry[:end_time]}".to_time(:utc)
      not_overlapped_time_entries += splitted_time_entries(start_time, end_time, date)
    end
    not_overlapped_time_entries
  end

  def splitted_time_entries(start_time, end_time, date)
    result = []
    time_entry_in_progress = [start_time, end_time]
    @time_off_in_range[date].each do |time_off|
      to_start_time = "#{DATE} #{time_off[:start_time]}".to_time(:utc)
      to_end_time = "#{DATE} #{time_off[:end_time]}".to_time(:utc)
      te_start_time = time_entry_in_progress.first
      te_end_time = time_entry_in_progress.last
      if to_start_time <= te_start_time && to_end_time >= te_end_time
        time_entry_in_progress = nil
        break
      elsif to_start_time < te_start_time && to_end_time < te_end_time &&
          to_end_time > te_start_time
        time_entry_in_progress = [to_end_time, te_end_time]
      elsif to_start_time > te_start_time && to_end_time > te_end_time &&
          to_start_time < te_end_time
        result.push([te_start_time, to_start_time])
        time_entry_in_progress = nil
      elsif to_start_time > te_start_time && to_end_time < te_end_time
        result.push([te_start_time, to_start_time])
        time_entry_in_progress = [to_end_time, te_end_time]
      end
    end
    time_entry_in_progress.present? ? result.push(time_entry_in_progress) : result
  end

  def format_time_entries(time_entries_in_time_format)
    time_entries_in_time_format.map do |time_entry|
      {
        type: 'working_time',
        start_time: time_entry.first.strftime('%H:%M:%S'),
        end_time: time_entry.last.strftime('%H:%M:%S')
      }
    end
  end
end
