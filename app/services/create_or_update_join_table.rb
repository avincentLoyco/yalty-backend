class CreateOrUpdateJoinTable
  include API::V1::Exceptions

  attr_reader :join_table_class, :params, :employee_join_tables, :join_table,
    :resource_class, :resource_class_id, :join_table_resource

  def initialize(join_table_class, resource_class, params, join_table_resource = nil)
    @join_table_class = join_table_class
    @params = params
    @resource_class = resource_class
    @resource_class_id = resource_class.model_name.singular + '_id'
    @join_table_resource = join_table_resource
    @status = 205
  end

  def call
    verify_effective_at_format
    @employee_join_tables = find_employees_join_tables
    ActiveRecord::Base.transaction do
      remove_duplicated_resources_join_tables
      [return_new_current_with_efective_till, @status]
    end
  end

  private

  def verify_effective_at_format
    Date.parse params[:effective_at]
  rescue
    raise InvalidParamTypeError.new(join_table_class, 'Effective_at must be a valid date')
  end

  def find_employees_join_tables
    join_tables_class = join_table_class.model_name.route_key
    if join_table_resource
      join_table_resource.employee.send(join_tables_class).where('id != ?', join_table_resource.id)
    else
      Account.current.employees.find(params[:id]).send(join_tables_class)
    end
  end

  def remove_duplicated_resources_join_tables
    join_tables_to_remove =
      FindJoinTablesToDelete.new(
        employee_join_tables,
        params[:effective_at],
        resource_class.find(resource_id),
        join_table_resource
      ).call
    remove_policy_assignation_balances(join_tables_to_remove)
    join_tables_to_remove.map(&:destroy!)
  end

  def remove_policy_assignation_balances(join_tables_to_remove)
    return unless join_table_class.eql?(EmployeeTimeOffPolicy)
    join_tables_to_remove.map(&:policy_assignation_balance).compact.map(&:destroy!)
  end

  def return_new_current_with_efective_till
    JoinTableWithEffectiveTill
      .new(join_table_class, Account.current.id, nil, nil, new_current_join_table.id, nil)
      .call
      .map { |join_hash| join_table_class.new(join_hash) }
      .first
  end

  def new_current_join_table
    if previous_join_table && previous_join_table.send(resource_class_id) == resource_id
      destroy_current_join_table if join_table_resource
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
    previous_effective_at = join_table_resource.effective_at
    join_table_resource.update!(params)
    update_assignation_balance(previous_effective_at)
    join_table_resource
  end

  def create_join_table
    @status = 201
    employee_join_tables.create!(params.except(:id))
  end

  def update_assignation_balance(effective_at)
    return unless join_table_class.eql?(EmployeeTimeOffPolicy) && effective_at
    assignation_balance = join_table_resource.policy_assignation_balance(effective_at)
    assignation_balance.update!(effective_at: params[:effective_at]) if assignation_balance
  end

  def previous_join_table
    employee_join_tables
      .where('effective_at < ?', params[:effective_at].to_date)
      .order(:effective_at)
      .last
  end

  def resource_id
    return params[resource_class_id.to_sym] unless join_table_resource
    join_table_resource.send(resource_class_id)
  end
end
