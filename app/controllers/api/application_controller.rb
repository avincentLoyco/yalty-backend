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

  protected

  def record_not_found_error(exception)
    render json: { status: "error", message: "Record not found" }, status: 404
  end
end
