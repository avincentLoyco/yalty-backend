class API::ApplicationController < ApplicationController
  before_action :authenticate!, :verify_employment!

  def current_user
    @current_user ||= Account::User.current
  end

  def current_ability
    @current_ability ||= AbilityFactory.build_for(current_user)
  end

  protected

  def resources
    raise NotImplementedError, "#{__method__} must be implemented in #{self.class.name}"
  end

  def resource
    raise NotImplementedError, "#{__method__} must be implemented in #{self.class.name}"
  end

  def resource_representer
    raise NotImplementedError, "#{__method__} must be implemented in #{self.class.name}"
  end

  private

  def authenticate!
    return unless Account.current.nil? || Account::User.current.nil?
    render json:
      ::Api::V1::ErrorsRepresenter.new(nil, error: ["User unauthorized"]).complete, status: 401
  end

  def verify_employment!
    return unless Account::User.current.present? && Account::User.current.inactive?
    render json:
      ::Api::V1::ErrorsRepresenter.new(nil, error: ["User inactive"]).complete, status: 401
  end

  def subdomain_access!
    return unless Account.current.nil?
    render json:
      ::Api::V1::ErrorsRepresenter.new(nil, error: ["User unauthorized"]).complete, status: 401
  end

  def update_affected_balances(presence_policy, employees = [])
    UpdateAffectedEmployeeBalances.new(presence_policy, employees).call
  end

  def next_balance(resource)
    RelativeEmployeeBalancesFinder.new(resource).next_balance
  end

  def create_or_update_join_table(resource_class, attributes, resource = nil)
    CreateOrUpdateJoinTable.new(
      controller_name.classify.constantize, resource_class, attributes, resource
    ).call
  end

  def destroy_join_tables_with_duplicated_resources
    employee_collection = resource.employee.send(resource.class.model_name.plural)
    related_resource = resource.send(resource.class.model_name.element.gsub("employee_", ""))
    contract_end = resource.employee.contract_end_for(resource.effective_at)
    if contract_end.eql?(resource.effective_at - 1.day)
      ::ContractEnds::Update.call(
        employee: resource.employee,
        new_contract_end_date: contract_end,
        old_contract_end_date: contract_end,
        event_id: resource.employee.event_at(date: contract_end, type: "contract_end")
      )
    else
      duplicated = FindSequenceJoinTableInTime.new(
        employee_collection, nil, related_resource, resource
      ).call
      return duplicated.map(&:destroy!) unless related_resource.class.eql?(TimeOffPolicy)
      duplicated.map(&:policy_assignation_balance).compact.map(&:destroy!)
      duplicated.map(&:destroy!)
    end
  end

  def clear_respective_reset_join_tables(employee, effective_at, time_off_category = nil,
    contract_end_destroy = nil)

    ClearResetJoinTables.new(employee, effective_at, time_off_category, contract_end_destroy).call
  end

  def resources_with_effective_till(join_table, join_table_id, related_id = nil, employee_id = nil)
    resources =
      JoinTableWithEffectiveTill
      .new(join_table, Account.current.id, related_id, employee_id, join_table_id)
      .call
    resources.map { |join_hash| join_table.new(join_hash) }
  end

  def resources_with_filters_and_effective_till(join_table, resource_id)
    resources =
      JoinTableWithEffectiveTill
      .new(join_table, Account.current.id, resource_id, nil, nil, nil)
      .call

    if params[:filter].eql?("inactive")
      resources = resources.select do |resource|
        resource["effective_till"].present? && resource["effective_till"].to_date < Time.zone.today
      end
    end

    resources.map { |join_hash| join_table.new(join_hash) }
  end

  def resources_with_filters(join_table, resource_id)
    if params[:filter].blank? || params[:filter].eql?("active")
      resources_with_effective_till(join_table, nil, resource_id)
    else
      resources_with_filters_and_effective_till(join_table, resource_id)
    end
  end

  def resources_by_status(resource_class, join_table_class)
    status = params[:status] == "inactive" ? "inactive" : "active"
    ActiveAndInactiveJoinTableFinders
      .new(resource_class, join_table_class, Account.current.id)
      .send(status)
  end

  def find_and_update_balances(join_table, attributes = {}, previous_effective_at = nil,
    resource = nil)

    new_effective_at = attributes[:effective_at] || join_table.effective_at
    params_for_service = [join_table, new_effective_at.to_date, previous_effective_at, resource]
    order_of_start_day = attributes[:order_of_start_day]
    previous_order_of_start_day = attributes[:previous_order_of_start_day]
    if order_of_start_day && order_of_start_day != join_table.order_of_start_day
      params_for_service.push(order_of_start_day)
    end
    return if join_table.class.eql?(EmployeePresencePolicy) && previous_effective_at.present? &&
        previous_effective_at == join_table.effective_at &&
        ((previous_order_of_start_day.present? && order_of_start_day.present? &&
        order_of_start_day == previous_order_of_start_day) || order_of_start_day.nil?)
    FindAndUpdateEmployeeBalancesForJoinTables.new(*params_for_service).call
  end

  def transactions
    ActiveRecord::Base.transaction do
      yield
    end
  end

  def render_resource(resource, options = {})
    representer = options.delete(:representer) || resource_representer

    response = if resource.respond_to?(:map)
                 resource.map { |item| representer.new(item).complete }
               else
                 representer.new(resource).complete
               end

    render options.merge(json: response)
  end

  def render_join_table(resource, status)
    return render_resource(resource, status: status) unless status.eql?(205)
    head :reset_content
  end

  def verify_if_resource_not_locked!(resource_type, resource_field = "employees")
    return unless resource_type.send(resource_field).present?
    raise generate_locked_error(resource_type.class.name.underscore, resource_field)
  end

  def internal_dispatcher
    @internal_dispatcher ||= InternalDispatcher.new
  end

  def email_dispatcher
    @email_dispatcher ||= EmailDispatcher.new
  end
end
