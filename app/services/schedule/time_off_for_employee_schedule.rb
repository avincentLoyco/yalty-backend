class TimeOffForEmployeeSchedule
  attr_reader :time_offs_in_range, :start_date, :end_date, :time_offs_hash

  def initialize(employee, start_date, end_date)
    @time_offs_in_range = TimeOff.for_employee_in_period(employee, start_date, end_date)
    @start_date = start_date
    @end_date = end_date
    @time_offs_hash = {}
  end

  def call
    return {} if time_offs_in_range.blank?
    populate_time_offs_hash
    time_offs_hash
  end

  private

  def populate_time_offs_hash
    time_offs_in_range.each do |time_off|
      time_offs_hash.merge!(generate_hash_for_time_off(time_off)) do |_key, val1, val2|
        val1.push(val2.first)
      end
    end
  end

  def generate_hash_for_time_off(time_off)
    TimeOffAsTimeEntriesForRange.new(start_date, end_date, time_off).call
  end
end
