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
    @time_off_in_range = TimeOffForEmployeeSchedule.new(@employee, @start_date, @end_date).call
    @working_times_in_range =
      RegisteredWorkingTimeForEmployeeSchedule.new(@employee, @start_date, @end_date).call
    @holidays_in_range = HolidaysForEmployeeSchedule.new(@employee, @start_date, @end_date).call
    @time_entries_in_range = TimeEntriesForEmployeeSchedule.new(@employee, @start_date, @end_date).call
    @calculated_schedule.each do |day_hash|
      date = day_hash[:date]
      working_times_and_holidays = @holidays_in_range[date] + @working_times_in_range[date]
      day_hash[:time_entries] += @time_off_in_range[date] + working_times_and_holidays
      prepare_working_time_from_presence_policy(day_hash) if working_times_and_holidays.empty?
    end
  end

  def prepare_working_time_from_presence_policy(day_hash)
    date = day_hash[:date]
    if @time_off_in_range[date].empty?
      day_hash[:time_entries] = @time_entries_in_range[date]
    else
      day_hash[:time_entries] +=
        format_time_entries(
          time_entries_not_overlapped_by_time_offs(date)
        )
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

  # Verifies if a time entry is overlapped or contained by any time off in the range given to
  # ScheduleForEmployee and if they are overlapped removes the overlapped parts and generates the
  # new time entries of the not overlapped parts.
  #
  # @param start_time [Time] start time of the time entry
  # @param end_time [Time] end time of the time entry
  #
  # @return [Array[Array[Time,Time]]] Every array is a time entry. The first time is the start_time
  #  of the time entry and the second time in the array is the end_time of the time entry.
  #
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
      elsif to_start_time <= te_start_time && to_end_time < te_end_time &&
          to_end_time > te_start_time
        time_entry_in_progress = [to_end_time, te_end_time]
      elsif to_start_time > te_start_time && to_end_time >= te_end_time &&
          to_start_time < te_end_time
        result.push([te_start_time, to_start_time])
        time_entry_in_progress = nil
        break
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
