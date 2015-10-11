class API::ApplicationController < ActionController::Base
  protect_from_forgery with: :null_session
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found_error

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

  def gate_member_rule
    Gate.rules do
      required :id, :String
    end
  end

  private

  def assign_collection(resource, collection, collection_name)
    AssignCollection.new(resource, collection, collection_name).call
  end

  def verified_params(rules)
    result = rules.verify(params)
    if result.valid?
      yield(result.attributes)
    else
      render json: ErrorsRepresenter.new(result.errors, 'settings').resource, status: 422
    end
  end

  def render_resource(resource, options = {})
    representer = options.delete(:representer) || resource_representer

    if resource.respond_to?(:map)
      response = resource.map {|item| representer.new(item).complete }
    else
      response = representer.new(resource).complete
    end

    render options.merge(json: response)
  end

  def render_no_content
    head 204
  end

  def render_error_json(resource)
    render json: ErrorsRepresenter.new(resource.errors.messages, resource.class.name.underscore)
      .resource, status: 422
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
