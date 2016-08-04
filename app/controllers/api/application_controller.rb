class API::ApplicationController < ApplicationController
  before_action :authenticate!

  def current_user
    @current_user ||= Account::User.current
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
      ::Api::V1::ErrorsRepresenter.new(nil, message: 'User unauthorized').complete, status: 401
  end

  def subdomain_access!
    return unless Account.current.nil?
    render json:
      ::Api::V1::ErrorsRepresenter.new(nil, message: 'User unauthorized').complete, status: 401
  end

  def assign_collection(resource, collection, collection_name)
    AssignCollection.new(resource, collection, collection_name).call
  end

  def assign_member(resource, member, member_name)
    AssignMember.new(resource, member, member_name).call
  end

  def update_affected_balances(presence_policy, employees = [])
    UpdateAffectedEmployeeBalances.new(presence_policy, employees).call
  end

  def prepare_balances_to_update(resource, attributes = {})
    PrepareEmployeeBalancesToUpdate.new(resource, attributes).call
  end

  def update_balances_job(resource, attributes = {})
    UpdateBalanceJob.perform_later(resource, attributes)
  end

  def next_balance(resource)
    RelativeEmployeeBalancesFinder.new(resource).next_balance
  end

  def create_or_update_join_table(join_table_class, resource_class, attributes, resource = nil)
    CreateOrUpdateJoinTable.new(join_table_class, resource_class, attributes, resource).call
  end

  def resources_with_effective_till(join_table, join_table_id, related_id = nil, employee_id = nil)
    resources =
      JoinTableWithEffectiveTill
      .new(join_table, Account.current.id, related_id, employee_id, join_table_id)
      .call
    resources.map { |join_hash| join_table.new(join_hash) }
  end

  def resources_by_status(resource_class, join_table_class)
    status = params[:status] == 'inactive' ? 'inactive' : 'active'
    ActiveAndInactiveJoinTableFinders
      .new(resource_class, join_table_class, Account.current.id)
      .send(status)
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
end
