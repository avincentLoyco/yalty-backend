class CreateOrUpdateJoinTable
  include API::V1::Exceptions

  attr_reader :join_table_class, :params, :employee_join_tables, :join_table,
    :resource_class, :join_table_resource

  def initialize(join_table_class, resource_class, params, join_table_resource = nil)
    @join_table_class = join_table_class
    @params = params
    @resource_class = resource_class.model_name.singular + '_id'
    @join_table_resource = join_table_resource
  end

  def call
    verify_effective_at_format
    find_employees_join_tables
    ActiveRecord::Base.transaction do
      remove_duplicated_resources_join_tables
      return_new_current_with_efective_till
    end
  end

  private

  def find_employees_join_tables
    @employee_join_tables =
      if join_table_resource
        employee.send(join_table_class.model_name.route_key)
                .where('id != ?', join_table_resource.id)
      else
        employee.send(join_table_class.model_name.route_key)
      end
  end

  def remove_duplicated_resources_join_tables
    FindJoinTablesToDelete.new(
      employee_join_tables, params[:effective_at], resource, resource_class, join_table_resource
    ).call.map(&:destroy!)
  end

  def employee
    return join_table_resource.employee if join_table_resource
    Account.current.employees.find(params.delete(:id))
  end

  def resource
    join_table_resource ? join_table_resource.send(resource_class) : params[resource_class.to_sym]
  end

  def new_current_join_table
    if previous_join_table && previous_join_table.send(resource_class) == resource
      join_table_resource.try(:destroy!)
      previous_join_table
    else
      create_or_update_join_table
    end
  end

  def create_or_update_join_table
    return employee_join_tables.create!(params) unless join_table_resource
    join_table_resource.tap { |resource| resource.update!(params) }
  end

  def previous_join_table
    effective_at = params[:effective_at].to_date
    employee_join_tables
      .where('effective_at < ?', effective_at)
      .order(:effective_at)
      .last
  end

  def verify_effective_at_format
    Date.parse params[:effective_at]
  rescue
    raise InvalidParamTypeError.new(join_table_class, 'Effective_at must be a valid date')
  end

  def return_new_current_with_efective_till
    JoinTableWithEffectiveTill
      .new(join_table_class, Account.current.id, nil, nil, new_current_join_table.id, nil)
      .call
      .map { |join_hash| join_table_class.new(join_hash) }
      .first
  end
end
