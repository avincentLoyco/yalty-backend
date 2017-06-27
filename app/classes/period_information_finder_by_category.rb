class PeriodInformationFinderByCategory
  def initialize(employee, time_off_category)
    @employee = employee
    @time_off_category = time_off_category
  end

  def find_period_for_date(date)
    current_etop = assigned_time_off_policy_at(date)
    return if current_etop.nil?
    start_date_of_period = find_period_start_date(date, current_etop.time_off_policy, current_etop)
    end_date_of_period = find_period_end_date(date)

    {
      type: current_etop.time_off_policy.policy_type,
      start_date: start_date_of_period,
      end_date: end_date_of_period,
      validity_date: find_validity_date_for_period(current_etop, start_date_of_period)
    }
  end

  private

  def find_validity_date_for_period(etop, start_date_of_period)
    validity_date = RelatedPolicyPeriod.new(etop).validity_date_for_balance_at(start_date_of_period)
    return unless validity_date.present?
    validity_date.to_date - 1.day
  end

  def find_period_start_date(date, top, etop)
    top_start_date = Date.new(date.year, top.start_month, top.start_day)
    top_start_date -= 1.year if top_start_date > date
    start_date_before_date_and_after_effective_at =
      (top_start_date <= date) && (top_start_date > etop.effective_at)
    start_date_before_date_and_after_effective_at ? top_start_date : etop.effective_at
  end

  def find_period_end_date(date)
    next_etop = assigned_time_off_policy_after(date)
    current_top = assigned_time_off_policy_at(date).time_off_policy
    current_top_next_start_date =
      Date.new(date.year, current_top.start_month, current_top.start_day)
    current_top_next_start_date += 1.year if current_top_next_start_date <= date
    condition =
      (current_top_next_start_date > date) &&
      (
        next_etop.nil? ||
        (next_etop.present? && current_top_next_start_date < next_etop.effective_at)
      )
    condition ? current_top_next_start_date - 1.day : next_etop.effective_at - 1.day
  end

  def assigned_time_off_policy_at(date)
    @current_etop ||=
      EmployeeTimeOffPolicy
      .not_reset
      .assigned_at(date)
      .by_employee_in_category(@employee.id, @time_off_category.id)
      .first
  end

  def assigned_time_off_policy_after(date)
    @next_etop ||=
      EmployeeTimeOffPolicy
      .not_assigned_at(date)
      .by_employee_in_category(@employee.id, @time_off_category.id)
      .last
  end
end
