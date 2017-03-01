module ExceptionHandler
  extend ActiveSupport::Concern
  include API::V1::Exceptions

  included do
    rescue_from Exception, with: :render_500_error
    rescue_from StandardError, with: :render_500_error
    rescue_from ActionController::RoutingError, with: :bad_request_error
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found_error
    rescue_from ActiveRecord::RecordInvalid, with: :resource_invalid_error
    rescue_from ActiveRecord::RecordNotDestroyed, with: :destroy_forbidden
    rescue_from InvalidParamTypeError, with: :invalid_param_type_error
    rescue_from EventTypeNotFoundError, with: :event_type_not_found
    rescue_from InvalidPasswordError, with: :invalid_password_error
    rescue_from InvalidResourcesError, with: :invalid_resources_error
    rescue_from CanCan::AccessDenied, with: :forbidden_error
    rescue_from CustomerNotCreated, with: :stripe_api_error
    rescue_from(
      Stripe::InvalidRequestError,
      Stripe::AuthenticationError,
      Stripe::PermissionError,
      Stripe::RateLimitError,
      Stripe::APIError
    ) do |exception|
      stripe_api_error(exception)
    end
  end

  private

  def stripe_api_error(exception = nil)
    message = exception.try(:message) ? exception.message : 'Stripe API error'
    render json:
      ::Api::V1::ErrorsRepresenter.new(nil, message: message).complete, status: 503
  end

  def render_no_content
    head 204
  end

  def resource_invalid_error(exception)
    resource = exception.try(:record) ? exception.record : exception
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

  def render_500_error(exception = nil)
    NewRelic::Agent.notice_error(exception) if exception
    resource = { resource: 'internal_server_error' }
    render json:
      ::Api::V1::ErrorsRepresenter.new(nil, resource).complete, status: 500
  end

  def bad_request_error
    resource = { resource: 'bad_request' }
    render json:
      ::Api::V1::ErrorsRepresenter.new(nil, resource).complete, status: 400
  end

  def forbidden_error(exception = nil)
    message = { message: exception.message }
    render json:
      ::Api::V1::ErrorsRepresenter.new(nil, message).complete, status: 403
  end

  def invalid_resources_error(exception)
    render json:
      ::Api::V1::ErrorsRepresenter.new(exception.resource, exception.messages).complete, status: 422
  end

  def invalid_password_error(exception)
    render json:
      ::Api::V1::ErrorsRepresenter.new(exception.resource, exception.message).complete, status: 403
  end

  def event_type_not_found(exception)
    render json:
      ::Api::V1::ErrorsRepresenter.new(exception.resource, exception.message).complete, status: 404
  end

  def invalid_param_type_error(exception)
    message = exception.message.is_a?(Hash) ? exception.message : { message: exception.message }
    render json:
      ::Api::V1::ErrorsRepresenter.new(exception.resource, message).complete, status: 422
  end

  def destroy_forbidden(exception)
    render json:
      ::Api::V1::ErrorsRepresenter.new(
        exception.record, exception.record.errors.messages
      ).complete, status: 403
  end
end
