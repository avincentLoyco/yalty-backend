class RegisteredWorkingTimeForEmployeeSchedule
  attr_reader :working_times, :working_times_hash, :end_date, :start_date

  def initialize(employee_id, start_date, end_date)
    @start_date = start_date
    @end_date = end_date
    @working_times = working_time_for_employee(employee_id)
    @working_times_hash = {}
  end

  def call
    create_time_offs_hash_structure
    populate_working_times_hash
    working_times_hash
  end

  private

  def create_time_offs_hash_structure
    calculate_time_range.times do |i|
      date = (start_date + i.days)
      working_times_hash[date.to_s] = []
    end
  end

  def calculate_time_range
    (end_date - start_date).to_i + 1
  end

  def working_time_for_employee(employee_id)
    RegisteredWorkingTime.for_employee_in_day_range(employee_id, start_date, end_date)
  end

  def populate_working_times_hash
    working_times.map do |working_time|
      working_times_hash.merge!(single_day_hash(working_time))
    end
  end

  def single_day_hash(working_time)
    {
      working_time.date.to_s => single_day_time_entires_hash(working_time[:time_entries])
    }
  end

  def single_day_time_entires_hash(time_entries)
    return [{}] unless time_entries.any?
    time_entries.map do |time_entry|
      {
        type: 'working_time',
        start_time: TimeEntry.hour_as_time(time_entry['start_time']).strftime('%H:%M:%S'),
        end_time: TimeEntry.hour_as_time(time_entry['end_time']).strftime('%H:%M:%S')
      }
    end
  end
end
