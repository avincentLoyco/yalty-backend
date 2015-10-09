class API::ApplicationController < ActionController::Base
  protect_from_forgery with: :null_session
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found_error

  def verified_params(rules)
    result = rules.verify(params)
    if result.valid?
      yield(result.attributes)
    else
      render json: ErrorsRepresenter.new(result.errors, 'settings').resource, status: 422
    end
  end

  def gate_member_rule
    Gate.rules do
      required :id, :String
    end
  end

  def render_error_json(resource)
    render json: ErrorsRepresenter.new(resource.errors.messages, resource.class.name.underscore)
      .resource, status: 422
  end

  def render_no_content
    render status: :no_content, nothing: true
  end

  def locked_error
    render json: { status: "error", message: "Locked" },
      status: 423
  end

  def method_not_allowed
    render json: { status: "error", message: "Method Not Allowed" },
      status: 405
  end

  def record_not_found_error
    render json: { status: "error", message: "Record not found" }, status: 404
  end

end
