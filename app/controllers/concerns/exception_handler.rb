module ExceptionHandler
  extend ActiveSupport::Concern
  include API::V1::Exceptions

  RESOURCE_TYPES = %w(presence_policy time_off_policies time_off_categories working_places)

  included do
    unless Rails.application.config.consider_all_requests_local
      rescue_from Exception, with: :render_500_error
      rescue_from StandardError, with: :render_500_error
    end
    rescue_from ActionController::RoutingError, with: :bad_request_error
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found_error
    rescue_from ActiveRecord::RecordInvalid, with: :resource_invalid_error
    rescue_from ActiveRecord::RecordNotDestroyed, with: :destroy_forbidden
    rescue_from CustomError, with: :custom_error
    rescue_from LockedError, with: :locked_error
    rescue_from EventTypeNotFoundError, with: :event_type_not_found
    rescue_from InvalidPasswordError, with: :invalid_password_error
    rescue_from InvalidResourcesError, with: :invalid_resources_error
    rescue_from CanCan::AccessDenied, with: :forbidden_error
    rescue_from(
      Stripe::CardError,
      Stripe::InvalidRequestError,
      Stripe::AuthenticationError,
      Stripe::PermissionError,
      Stripe::RateLimitError,
      Stripe::APIError
    ) do |exception|
      stripe_error(exception)
    end
    rescue_from(
      CustomerNotCreated,
      StripeError
    ) do |exception|
      render_stripe_error(exception)
    end
  end

  private

  def stripe_error(_exception)
    raise NotImplementedError, "#{__method__} must be implemented in #{self.class.name}"
  end

  def render_stripe_error(exception)
    render json: ::Api::V1::StripeErrorRepresenter.new(exception).complete, status: 502
  end

  def render_no_content
    head 204
  end

  def resource_invalid_error(exception)
    resource = exception.try(:record) ? exception.record : exception
    render json:
      ::Api::V1::ErrorsRepresenter.new(resource).complete, status: 422
  end

  def generate_locked_error(type, field)
    LockedError.new(
      type: type,
      field: field,
      messages: [get_message(type)],
      codes: [get_code(type)]
    )
  end

  def render_locked_error(type, field)
    exception = LockedError.new(
      type: type,
      field: field,
      messages: [get_message(type)],
      codes: [get_code(type)]
    )
    render json: ::Api::V1::ErrorsRepresenter.new(exception).complete, status: 423
  end

  def record_not_found_error(exception = nil)
    resource = exception.record if exception && exception.respond_to?(:record)

    error = CustomError.new(
      type: resource,
      field: "id",
      messages: ["Record Not Found"],
      codes: ["error_record_not_found"]
    )

    render json:
      ::Api::V1::ErrorsRepresenter.new(error).complete, status: 404
  end

  def render_500_error(exception = nil)
    NewRelic::Agent.notice_error(exception) if exception
    error = CustomError.new(
      messages: ["internal server error"],
      codes: ["error_internal_server_error"]
    )
    render json:
      ::Api::V1::ErrorsRepresenter.new(error).complete, status: 500
  end

  def bad_request_error
    error = CustomError.new(
      messages: ["Bad request"],
      codes: ["error_bad_request"]
    )
    render json:
      ::Api::V1::ErrorsRepresenter.new(error).complete, status: 400
  end

  def forbidden_error(exception = nil)
    messages = { error: [exception.message] }
    render json:
      ::Api::V1::ErrorsRepresenter.new(nil, messages).complete, status: 403
  end

  def invalid_resources_error(exception)
    render json:
      ::Api::V1::ErrorsRepresenter.new(exception.resource, exception.messages).complete, status: 422
  end

  def invalid_password_error(exception)
    render json:
      ::Api::V1::ErrorsRepresenter.new(exception.resource, exception.messages).complete, status: 403
  end

  def event_type_not_found(exception)
    render json:
      ::Api::V1::ErrorsRepresenter.new(exception.resource, exception.messages).complete, status: 404
  end

  def custom_error(exception)
    render json: ::Api::V1::ErrorsRepresenter.new(exception).complete, status: 422
  end

  def locked_error(exception)
    render json: ::Api::V1::ErrorsRepresenter.new(exception).complete, status: 423
  end

  def destroy_forbidden(exception)
    render json:
      ::Api::V1::ErrorsRepresenter.new(
        exception.record, exception.record.errors.messages
      ).complete, status: 403
  end

  def get_message(type)
    if RESOURCE_TYPES.include?(type)
      "Resource is locked because #{type} has assigned employees to it"
    else
      "Resource is locked because employee attributes are not blank"
    end
  end

  def get_code(type)
    if RESOURCE_TYPES.include?(type)
      "#{type}_employees_present"
    else
      "employee_attributes_not_blank"
    end
  end
end
