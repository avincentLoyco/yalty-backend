class HolidaysForEmployeeInRange
  attr_reader :employee, :range_start, :range_end, :active_employee_working_places,
    :holidays_in_period

  def initialize(employee, range_start, range_end)
    @employee = employee
    @range_start = range_start
    @range_end = range_end
    @holidays_in_period = []
  end

  def call
    find_active_working_places_in_range
    find_holidays_for_active_working_places
    holidays_in_period.flatten
  end

  private

  def find_active_working_places_in_range
    @active_employee_working_places =
      JoinTableWithEffectiveTill
      .new(EmployeeWorkingPlace, employee.account_id, nil, employee.id, nil, range_start, range_end)
      .call
      .map { |join_table_hash| EmployeeWorkingPlace.new(join_table_hash) }
  end

  def find_holidays_for_active_working_places
    active_employee_working_places.each do |active|
      holiday_policy = active.working_place.holiday_policy
      next unless holiday_policy
      start_date, end_date = period_interval_for_employee_working_place(active)
      holidays_in_period << holiday_policy.holidays_in_period(start_date, end_date)
    end
  end

  def period_interval_for_employee_working_place(active)
    [active_employee_working_places.first == active ? range_start : active.effective_at.to_date,
     active_employee_working_places.last == active ? range_end : active.effective_till.to_date]
  end
end
