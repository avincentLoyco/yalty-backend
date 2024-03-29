class CreateOrUpdateJoinTable
  include API::V1::Exceptions

  attr_reader :join_table_class, :params, :employee_join_tables, :join_table,
    :resource_class, :resource_class_id, :join_table_resource, :current_account,
    :join_table_old_effective_at

  def self.call(join_table_class, resource_class, params, join_table_resource = nil)
    new(join_table_class, resource_class, params, join_table_resource).call
  end

  def initialize(join_table_class, resource_class, params, join_table_resource = nil)
    @join_table_class = join_table_class
    @params = params
    @resource_class = resource_class
    @resource_class_id = resource_class.model_name.singular + "_id"
    @join_table_resource = join_table_resource
    @join_table_old_effective_at = join_table_resource.try(:effective_at)
    @status = 205
    @current_account = employee.account
  end

  def call
    @employee_join_tables = find_employees_join_tables
    ActiveRecord::Base.transaction do
      remove_duplicated_resources_join_tables
      { result: return_new_current_with_effective_till, status: @status }
    end
  end

  private

  def find_employees_join_tables
    join_tables_class = join_table_class.model_name.route_key
    return employee.send(join_tables_class) unless join_table_resource
    employee.send(join_tables_class).where.not(id: join_table_resource.id)
  end

  def remove_duplicated_resources_join_tables
    join_tables_to_remove =
      FindSequenceJoinTableInTime.new(
        employee_join_tables,
        params[:effective_at],
        resource_class.find(resource_id),
        join_table_resource
      ).call
    remove_policy_assignation_balances(join_tables_to_remove)
    reassignation = find_reassignation(join_tables_to_remove)
    join_tables_to_remove.delete(reassignation)
    reassignation.try(:delete)
    join_tables_to_remove.map(&:destroy!)
  end

  def remove_policy_assignation_balances(join_tables_to_remove)
    return unless join_table_class.eql?(EmployeeTimeOffPolicy)
    join_tables_to_remove.map(&:policy_assignation_balance).compact.map do |balance|
      DestroyEmployeeBalance.call(balance, update: false) unless balance.balance_type.eql?("reset")
    end
  end

  def find_reassignation(join_tables)
    return unless join_table_class.eql?(EmployeeTimeOffPolicy)
    join_tables.find { |table| table[:effective_at].eql?(params[:effective_at]) }
  end

  def return_new_current_with_effective_till
    join_table_hash =
      JoinTableWithEffectiveTill
      .new(join_table_class, current_account.id, nil, nil, new_current_join_table.id, nil)
      .call
      .first
    join_table_class.new(join_table_hash)
  end

  def new_current_join_table
    if [TimeOffPolicy, PresencePolicy].exclude?(resource_class) && previous_join_table &&
        previous_join_table.send(resource_class_id).eql?(resource_id) &&
        previous_in_the_same_period?
      destroy_current_join_table if join_table_resource
      create_reset_join_table_after_update(previous_join_table)
      previous_join_table
    else
      join_table_resource.present? ? update_current_join_table : create_join_table
    end
  end

  def destroy_current_join_table
    if join_table_class.eql?(EmployeeTimeOffPolicy)
      join_table_resource.policy_assignation_balance.try(:destroy!)
    end
    join_table_resource.destroy!
  end

  def update_current_join_table
    @status = 200
    return update_with_assignation_balance if join_table_class.eql?(EmployeeTimeOffPolicy)
    join_table_resource.update!(params)
    join_table_resource.tap { |join_table| create_reset_join_table_after_update(join_table) }
  end

  def update_with_assignation_balance
    assignation_balance = join_table_resource.policy_assignation_balance
    join_table_resource.update!(params)
    if assignation_balance &&
        !join_table_resource.employee.contract_periods_include?(assignation_balance.effective_at)
      if related_balances.present?
        DestroyEmployeeBalance.new(assignation_balance, update: false).call
      else
        UpdateEmployeeBalance.new(
          assignation_balance, effective_at: assignation_effective_at
        ).call
      end
    end
    join_table_resource.tap { |join_table| create_reset_join_table_after_update(join_table) }
  end

  def create_join_table
    @status = 201
    employee_join_tables.create!(params.except(:employee_id)).tap do |join_table|
      upcoming_contract_end =
        join_table.employee.first_upcoming_contract_end(join_table.effective_at)
      next unless upcoming_contract_end.present? &&
          join_table.effective_at <= upcoming_contract_end.effective_at
      create_reset_join_table(join_table, upcoming_contract_end.effective_at)
    end
  end

  def create_reset_join_table_after_update(join_table)
    return if join_table_old_effective_at.blank? ||
        join_table_old_effective_at.eql?(join_table.effective_at)

    before_contract_end = employee.contract_end_for(join_table_old_effective_at)
    next_contract_end =
      employee.first_upcoming_contract_end(join_table.effective_at).try(:effective_at)

    if before_contract_end.present? && join_table_old_effective_at.eql?(before_contract_end + 1.day)
      create_reset_join_table(join_table, before_contract_end)
    end

    create_reset_join_table(join_table, next_contract_end) if next_contract_end.present?
  end

  def create_reset_join_table(join_table, effective_at = nil)
    join_table_name = resource_class.name.underscore.pluralize
    to_category = join_table.try(:time_off_category)
    AssignResetJoinTable.new(join_table_name, employee, to_category, effective_at).call
    ClearResetJoinTables.new(employee, join_table_old_effective_at, to_category).call
  end

  def previous_join_table
    join_tables =
      employee_join_tables
      .where("effective_at < ?", params[:effective_at].to_date).order(:effective_at)
    return join_tables.last unless join_table_class.eql?(EmployeeTimeOffPolicy)
    join_tables.where(time_off_category_id: time_off_category_id).last
  end

  def resource_id
    return params[resource_class_id.to_sym] unless join_table_resource
    join_table_resource.send(resource_class_id)
  end

  def related_balances
    Employee::Balance
      .where(
        time_off_category_id: join_table_resource.time_off_category_id,
        employee_id: employee.id,
        effective_at: assignation_effective_at
      )
  end

  def assignation_effective_at
    params[:effective_at] + Employee::Balance::ASSIGNATION_OFFSET
  end

  def time_off_category_id
    resource_class.where(id: resource_id).first.time_off_category_id
  end

  def employee
    @employee ||= join_table_resource.try(:employee) || Employee.find(params[:employee_id])
  end

  def previous_in_the_same_period?
    employee.contract_periods_include?(params[:effective_at], previous_join_table.effective_at)
  end
end
