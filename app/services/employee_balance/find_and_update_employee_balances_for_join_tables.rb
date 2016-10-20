class FindAndUpdateEmployeeBalancesForJoinTables
  attr_reader :join_table, :new_date, :previous_date, :resource_at_previous_date

  def initialize(join_table, new_date, previous_date = nil, resource_at_previous_date = nil)
    @join_table = join_table
    @new_date = new_date
    @previous_date = previous_date
    @resource_at_previous_date = resource_at_previous_date
  end

  def call
    date = find_date_from_effective_at
    return unless date.present?
    group_and_update_employee_balances(date)
  end

  private

  def find_date_from_effective_at
    return find_date_from_resource_class if join_table.class.eql?(EmployeeWorkingPlace)
    new_date && previous_date ? find_older : new_date
  end

  def find_older
    new_date > previous_date ? previous_date : new_date
  end

  def find_date_from_resource_class
    return verify_for_previous_and_new if previous_date.present?
    new_date if holiday_policy_changed_at_date?(new_date)
  end

  def group_and_update_employee_balances(date)
    employee_balances_for(date).group_by { |b| b[:time_off_category_id] }.each do |_k, v|
      PrepareEmployeeBalancesToUpdate.new(v.first, update_all: true).call
      UpdateBalanceJob.perform_later(v.first.id, update_all: true)
    end
  end

  def verify_for_previous_and_new
    if previous_date > new_date
      return new_date if holiday_policy_changed_at_date?(new_date)
      previous_date if holiday_policy_changed_at_date?(previous_date)
    else
      return previous_date if holiday_policy_changed_at_date?(previous_date)
      new_date if holiday_policy_changed_at_date?(new_date)
    end
  end

  def holiday_policy_changed_at_date?(date)
    if previous_date.present? && date == previous_date
      previous_resource(date) != current_holiday_policy
    else
      (resource_at_previous_date &&
        resource_at_previous_date.holiday_policy_id != current_holiday_policy) ||
        (previous_resource(date) != current_holiday_policy && resource_at_previous_date.nil?)
    end
  end

  def current_holiday_policy
    @current_holiday_policy ||= join_table.working_place.holiday_policy_id
  end

  def previous_resource(date)
    join_table
      .class
      .where('effective_at < ? AND employee_id = ?', date, join_table.employee.id)
      .order(:effective_at)
      .last
      .try(:working_place)
      .try(:holiday_policy_id)
  end

  def employee_balances_for(date)
    join_table
      .employee
      .employee_balances
      .where.not(time_off_id: nil)
      .where('effective_at >= ?', date)
      .order(:effective_at)
  end
end
