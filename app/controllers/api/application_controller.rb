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

  def assign_join_table_collection(resource, collection, collection_name)
    AssignJoinTableCollection.new(resource, collection, collection_name).call
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
