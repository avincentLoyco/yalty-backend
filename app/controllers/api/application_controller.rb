class API::ApplicationController < ActionController::Base
  include API::V1::Exceptions
  protect_from_forgery with: :null_session
  before_action :authenticate!

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found_error
  rescue_from InvalidResourcesError, with: :invalid_resources_error

  protected

  def resources
    fail NotImplementedError, "#{__method__} must be implemented in #{self.class.name}"
  end

  def resource
    fail NotImplementedError, "#{__method__} must be implemented in #{self.class.name}"
  end

  def resource_representer
    fail NotImplementedError, "#{__method__} must be implemented in #{self.class.name}"
  end

  private

  def authenticate!
    return unless Account.current.nil? || Account::User.current.nil?
    render json:
      ::Api::V1::ErrorsRepresenter.new(nil, message: 'User unauthorized').complete, status: 401
  end

  def assign_collection(resource, collection, collection_name)
    AssignCollection.new(resource, collection, collection_name).call
  end

  def assign_member(resource, member, member_name)
    AssignMember.new(resource, member, member_name).call
  end

  def verified_params(rules)
    result = rules.verify(params)
    if result.valid?
      yield(result.attributes)
    else
      render json:
        ::Api::V1::ErrorsRepresenter.new(result).complete, status: 422
    end
  end

  def transactions
    ActiveRecord::Base.transaction do
      yield
    end
  end

  def render_resource(resource, options = {})
    representer = options.delete(:representer) || resource_representer

    if resource.respond_to?(:map)
      response = resource.map { |item| representer.new(item).complete }
    else
      response = representer.new(resource).complete
    end

    render options.merge(json: response)
  end

  def render_no_content
    head 204
  end

  def resource_invalid_error(resource)
    render json:
      ::Api::V1::ErrorsRepresenter.new(resource).complete, status: 422
  end

  def locked_error
    render json:
      ::Api::V1::ErrorsRepresenter.new(nil, resource: 'Locked').complete, status: 423
  end

  def record_not_found_error(exception = nil)
    if exception && exception.respond_to?(:record)
      resource = exception.record
    else
      message = { id: 'Record Not Found' }
    end

    render json:
      ::Api::V1::ErrorsRepresenter.new(resource, message).complete, status: 404
  end

  def invalid_resources_error(exception)
    render json:
      ::Api::V1::ErrorsRepresenter.new(exception.resource, exception.messages).complete, status: 422
  end
end
