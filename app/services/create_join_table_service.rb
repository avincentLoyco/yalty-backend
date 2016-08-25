class CreateJoinTableService
  include API::V1::Exceptions

  attr_reader :join_table_class, :params, :employee, :employee_join_tables,
    :join_table, :current_join_table, :resource_class

  def initialize(join_table_class, resource_class, params)
    @join_table_class = join_table_class
    @params = params
    @resource_class = resource_class.model_name.singular + '_id'
    @current_join_table = nil
  end

  def call
    verify_effective_at_format
    find_employee
    find_employees_join_tables
    find_current_join_table
    manage_join_tables
    return_new_current_with_efective_till
  end

  private

  def find_employee
    @employee = Account.current.employees.find(params.delete(:id))
  end

  def find_employees_join_tables
    @employee_join_tables = employee.send(join_table_class.model_name.route_key)
  end

  def find_current_join_table
    @current_join_table = employee_join_tables.find_by(effective_at: params[:effective_at].to_date)
    verify_if_resource_not_duplicated
  end

  def verify_effective_at_format
    Date.parse params[:effective_at]
  rescue
    raise InvalidParamTypeError.new(join_table_class, 'Effetive_at must be a valid date')
  end

  def verify_if_resource_not_duplicated
    return unless current_join_table.try(:send, resource_class) == params[resource_class.to_sym]
    raise InvalidResourcesError.new(
      join_table_class, ['Join Table with given date and resource already exists']
    )
  end

  def manage_join_tables
    remove_duplicated_resources_join_tables
    if previous_join_table.try(:send, resource_class) == params[resource_class.to_sym]
      @current_join_table = previous_join_table
    else
      @current_join_table = employee_join_tables.create!(params)
    end
  end

  def return_new_current_with_efective_till
    JoinTableWithEffectiveTill
      .new(join_table_class, Account.current.id, nil, nil, current_join_table.id, nil)
      .call
      .map { |join_hash| join_table_class.new(join_hash) }
      .first
  end

  def remove_duplicated_resources_join_tables
    join_tables_to_remove = []
    join_tables_to_remove.push(current_join_table) if current_join_table
    if next_join_table.try(:send, resource_class) == params[resource_class.to_sym]
      join_tables_to_remove.push(next_join_table)
    end
    remove_employee_balances(join_tables_to_remove) if join_table_class == EmployeeTimeOffPolicy
    join_tables_to_remove.map(&:destroy!)
  end

  def remove_employee_balances(join_tables_to_remove)
    join_tables_to_remove.map(&:employee_balances).map(&:destroy_all)
  end

  def previous_join_table
    employee_join_tables
      .where('effective_at < ?', params[:effective_at].to_date)
      .order(:effective_at)
      .last
  end

  def next_join_table
    employee_join_tables
      .where('effective_at > ?', params[:effective_at].to_date)
      .order(:effective_at)
      .first
  end
end
