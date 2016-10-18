class FindAndUpdateEmployeeBalancesForJoinTables
  attr_reader :join_table, :employee, :new_date, :previous_date,
    :current_resource, :existing_resource

  def initialize(join_table, employee, new_date, previous_date = nil, existing_resource = nil)
    @join_table = join_table
    @employee = employee
    @new_date = new_date
    @previous_date = previous_date
    @existing_resource = existing_resource
  end

  def call
    find_resource
    date = find_date_from_effective_at
    return unless date.present? && employee_balances_for(date).present?
    employee_balances_for(date).group_by { |b| b[:time_off_category_id] }.each do |_k, v|
      PrepareEmployeeBalancesToUpdate.new(v.first).call
      UpdateBalanceJob.perform_later(v.first.id)
    end
  end

  private

  def find_resource
    @current_resource =
      if join_table.class.eql?(EmployeeWorkingPlace)
        join_table.working_place.holiday_policy_id
      end
  end

  def find_date_from_effective_at
    return find_date_from_resource_class if join_table.class.eql?(EmployeeWorkingPlace)
    new_date && previous_date ? find_older : new_date
  end

  def find_older
    new_date > previous_date ? previous_date : new_date
  end

  def find_date_from_resource_class
    return verify_for_previous_and_new if previous_date.present?
    return new_date if resource_changed?
  end

  def verify_for_previous_and_new
    if previous_date > new_date
      return new_date if resource_changed?
      return previous_date if resource_changed?(previous_date)
    else
      return previous_date if resource_changed?(previous_date)
      return new_date if resource_changed?
    end
  end

  def resource_changed?(date = new_date)
    if previous_date.present? && date == previous_date
      previous_resource(date) != current_resource
    else
      (existing_resource && existing_resource.holiday_policy_id != current_resource) ||
        (previous_resource(date) != current_resource && existing_resource.nil?)
    end
  end

  def previous_resource(date)
    join_table
      .class
      .where('effective_at < ? AND employee_id = ?', date, employee.id)
      .order(:effective_at)
      .last
      .try(:working_place)
      .try(:holiday_policy_id)
  end

  def employee_balances_for(date)
    employee
      .employee_balances
      .where.not(time_off_id: nil)
      .where('effective_at >= ?', date)
      .order(:effective_at)
  end
end
