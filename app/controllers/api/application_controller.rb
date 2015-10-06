class API::ApplicationController < ActionController::Base
  protect_from_forgery with: :null_session

  def with_verified_params(rules)
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
end
