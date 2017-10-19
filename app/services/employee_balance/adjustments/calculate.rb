class Adjustments::Calculate
  attr_reader :employee_id

  MINUTES_IN_A_DAY = 24 * 60

  def initialize(employee_id)
    @employee_id = employee_id
  end

  def call
    (adjustment * MINUTES_IN_A_DAY).round
  end

  private

  def leap_year?
    Date.gregorian_leap?(current_etop_or_contract_end.effective_at.year)
  end

  def adjustment
    if hired_or_rehired_event
      calculate_current_adjustment
    elsif contract_end_event
      calculate_for_end_of_contract_event
    elsif work_contract_event
      calculate_with_previous_adjustment
    end
  end

  def hired_or_rehired_event
    current_etop && !previous_etop && Employee.find(employee_id).events.length == 1 ||
      current_etop && contract_end && hired_event.effective_at > contract_end.effective_at
  end

  def work_contract_event
    current_etop && previous_etop
  end

  def contract_end_event
    contract_end && contract_end.effective_at > current_etop.effective_at &&
      hired_event.effective_at < contract_end.effective_at
  end

  def calculate_with_previous_adjustment
    previous_annual_allowance = annual_allowance(previous_etop)
    current_annual_allowance = annual_allowance(current_etop)
    calculated_annual_allowance = -previous_annual_allowance + current_annual_allowance

    calculated_annual_allowance / days_in_a_year * number_of_days_until_end_of_year
  end

  def calculate_current_adjustment
    annual_allowance(current_etop) / days_in_a_year * number_of_days_until_end_of_year
  end

  def calculate_for_end_of_contract_event
    previous_annual_allowance = annual_allowance(current_etop)
    number_of_days_until_end_of_year * (-previous_annual_allowance / days_in_a_year)
  end

  def annual_allowance(etop)
    (etop.time_off_policy.amount / 60.0 / 24.0) * etop.occupation_rate
  end

  def number_of_days_until_end_of_year
    effective_at = current_etop_or_contract_end.effective_at
    last_day_of_year = Date.new(effective_at.year, 12, 31)
    including_assignation_day = 1
    (last_day_of_year - effective_at + including_assignation_day).to_i
  end

  def current_etop_or_contract_end
    contract_end || current_etop
  end

  def days_in_a_year
    leap_year? ? 366 : 365
  end

  def current_etop
    all_vacation_etops.sort_by(&:effective_at).last
  end

  def previous_etop
    two_last_etops = all_vacation_etops.sort_by(&:effective_at).last(2)
    two_last_etops.length > 1 ? two_last_etops.first : nil
  end

  def contract_end
    employee_events = Employee.find(employee_id).events
    contract_end_events = employee_events.select do |employee_event|
      employee_event.event_type == 'contract_end'
    end
    contract_end_events.sort_by(&:effective_at).last
  end

  def hired_event
    employee_events = Employee.find(employee_id).events
    hired_events = employee_events.select do |employee_event|
      employee_event.event_type == 'hired'
    end
    hired_events.sort_by(&:effective_at).last
  end

  def all_vacation_etops
    all_etops = Employee.find(employee_id).employee_time_off_policies
    vacation_etops = all_etops.select do |etop|
      etop.time_off_category.name == 'vacation' && !etop.time_off_policy.reset
    end
    vacation_etops
  end
end
