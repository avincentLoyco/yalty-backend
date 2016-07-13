class ScheduleForEmployee
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
        SplitTimeEntriesByTimeEntriesForDate.new(
          @time_entries_in_range[date],
          @time_off_in_range[date],
          'working_time'
        ).call
    end
  end
end
