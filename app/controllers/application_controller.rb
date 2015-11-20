class ApplicationController < ActionController::Base
  include API::V1::Exceptions
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :null_session
  include GateParamsVerification

  rescue_from Exception, with: :render_500_error
  rescue_from StandardError, with: :render_500_error
  rescue_from ActionController::RoutingError, with: :bad_request_error
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found_error
  rescue_from InvalidPasswordError, with: :invalid_password_error
  rescue_from InvalidResourcesError, with: :invalid_resources_error

  private

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

  def render_500_error
    resource = { resource: 'internal_server_error' }
    render json:
      ::Api::V1::ErrorsRepresenter.new(nil, resource).complete, status: 500
  end

  def bad_request_error
    resource = { resource: 'bad_request' }
    render json:
      ::Api::V1::ErrorsRepresenter.new(nil, resource).complete, status: 400
  end

  def invalid_resources_error(exception)
    render json:
      ::Api::V1::ErrorsRepresenter.new(exception.resource, exception.messages).complete, status: 422
  end

  def invalid_password_error(exception)
    render json:
      ::Api::V1::ErrorsRepresenter.new(exception.resource, exception.message).complete, status: 403
  end
end
