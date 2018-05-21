class HolidaysForEmployeeSchedule
  attr_reader :holidays_in_range, :holidays_hash, :start_date, :end_date

  def initialize(employee, start_date, end_date)
    @start_date = start_date
    @end_date = end_date
    @holidays_in_range = HolidaysForEmployeeInRange.new(employee, start_date, end_date).call
    @holidays_hash = {}
  end

  def call
    create_holidays_hash_structure
    form_holidays_hash
    holidays_hash
  end

  private

  def create_holidays_hash_structure
    calculate_time_range.times do |i|
      date = (start_date + i.days)
      holidays_hash[date.to_s] = []
    end
  end

  def calculate_time_range
    (end_date - start_date).to_i + 1
  end

  def form_holidays_hash
    holidays_in_range.each do |holiday|
      holidays_hash.merge!(single_holiday_hash(holiday))
    end
  end

  def single_holiday_hash(holiday)
    {
      holiday.date.to_s => [
        {
          type: "holiday",
          name: holiday.name,
        },
      ],
    }
  end
end
