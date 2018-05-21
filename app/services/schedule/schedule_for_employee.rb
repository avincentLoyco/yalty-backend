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
          time_entries: [],
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
    @comments_in_range = prepare_working_day_comments
    @holidays_in_range = HolidaysForEmployeeSchedule.new(@employee, @start_date, @end_date).call
    @time_entries_in_range =
      TimeEntriesForEmployeeSchedule.new(@employee, @start_date, @end_date).call
    @calculated_schedule.each do |day_hash|
      date = day_hash[:date]
      day_registered_working_times = @working_times_in_range[date]
      working_times_and_holidays =
        @holidays_in_range[date] + day_registered_working_times.reject(&:empty?)
      day_hash[:time_entries] += @time_off_in_range[date] + working_times_and_holidays
      if working_times_and_holidays.empty? && day_registered_working_times.empty?
        prepare_working_time_from_presence_policy(day_hash)
      end
      day_hash[:comment] = @comments_in_range[date] if @comments_in_range.key?(date)
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
          "working_time"
        ).call
    end
  end

  def prepare_working_day_comments
    RegisteredWorkingTime
      .for_employee_in_day_range(@employee.id, @start_date, @end_date)
      .pluck(:date, :comment)
      .each_with_object({}) { |day, days| days[day[0].to_s] = day[1] }
  end
end
