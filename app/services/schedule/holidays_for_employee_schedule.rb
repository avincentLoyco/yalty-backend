class HolidaysForEmployeeSchedule
  attr_reader :holidays_in_range, :holidays_hash

  def initialize(employee, range_start, range_end)
    @holidays_in_range = HolidaysForEmployeeInRange.new(employee, range_start, range_end).call
    @holidays_hash = {}
  end

  def call
    return {} if holidays_in_range.blank?
    form_holidays_hash
    holidays_hash
  end

  private

  def form_holidays_hash
    holidays_in_range.each do |holiday|
      holidays_hash.merge!(single_holiday_hash(holiday))
    end
  end

  def single_holiday_hash(holiday)
    {
      holiday.date.to_s => {
        type: 'holiday',
        name: holiday.name
      }
    }
  end
end
