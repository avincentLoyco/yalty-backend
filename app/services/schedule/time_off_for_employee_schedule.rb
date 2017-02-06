class TimeOffForEmployeeSchedule
  attr_reader :time_offs_in_range, :start_date, :end_date, :time_offs_hash, :employee

  def initialize(employee, start_date, end_date)
    @employee = employee
    @time_offs_in_range = TimeOff.for_employee_in_period(employee, start_date, end_date)
    @start_date = start_date
    @end_date = end_date
    @time_offs_hash = {}
    @single_employee = employee.is_a?(Employee)
  end

  def call
    create_time_offs_hash_structure
    if @single_employee
      populate_time_offs_hash_for_one_employee
    else
      populate_time_offs_hash_for_many_employees
    end
    time_offs_hash
  end

  private

  def create_time_offs_hash_structure
    calculate_time_range.times do |i|
      date = (start_date + i.days)
      time_offs_hash[date.to_s] = @single_employee ? [] : {}
    end
  end

  def calculate_time_range
    (end_date - start_date).to_i + 1
  end

  def populate_time_offs_hash_for_one_employee
    time_offs_in_range.each do |time_off|
      time_offs_hash.merge!(generate_hash_for_time_off(time_off, false)) do |_key, val1, val2|
        val1.push(val2.first)
      end
    end
  end

  def populate_time_offs_hash_for_many_employees
    time_offs_in_range.each do |time_off|
      time_offs_hash
        .merge!(generate_hash_for_time_off(time_off, true)) do |_key, employe_hash1, employe_hash2|
        employe_hash1.merge!(employe_hash2) do |_key, val1, val2|
          val1.push(val2.first)
        end
      end
    end
  end

  def generate_hash_for_time_off(time_off, grouped_by_employee)
    start_time = Time.zone.local(start_date.to_s)
    end_time = Time.zone.local(end_date.year, end_date.month, end_date.day, 23, 59, 59)
    TimeOffAsTimeEntriesForRange.new(start_time, end_time, time_off, grouped_by_employee).call
  end
end
