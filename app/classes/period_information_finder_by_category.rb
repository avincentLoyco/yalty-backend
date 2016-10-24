class PeriodInformationFinderByCategory
  def initialize(employee, time_off_category)
    @employee = employee
    @time_off_category = time_off_category
  end

  def find_period_for_date(date)
    period_start_date = find_period_start_date(date, active_etop_at_date)
    period_end_date = nil
  end

  private

  def find_period_start_date(date, etop)
    top = assigned_time_off_policy_at
    top_start_date = Date.new(date.year, top.start_month, top.start_day)
    start_date_before_date_and_after_effective_at =
      (top_start_date < date) && (top_start_date > etop.effective_at)
    start_date_before_date_and_after_effective_at ? top_start_date : etop.effective_at
  end

  def find_period_end_date(date)
    next_top = assigned_time_off_policy_after(date).time_off_policy
    current_top =  assigned_time_off_policy_at(date).time_off_policy
    current_top_start_date = Date.new(date.year, top.start_month, top.start_day)
    start_date_before_date_and_after_effective_at =
      (top_start_date < date) && (top_start_date > etop.effective_at)
    start_date_before_date_and_after_effective_at ? top_start_date : etop.effective_at
  end

  def assigned_time_off_policy_at(date)
    @current_etop ||=
      EmployeeTimeOffPolicy
      .assigned_at(date)
      .by_employee_in_category(@employee.id, @time_off_category.id)
      .last
  end

  def assigned_time_off_policy_after(date)
    @next_etop ||=
      EmployeeTimeOffPolicy
      .not_assigned_at(date)
      .by_employee_in_category(@employee.id, @time_off_category.id)
      .last
  end
end
