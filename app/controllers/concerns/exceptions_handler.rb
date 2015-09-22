module ExceptionsHandler
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  end

  private

  def record_invalid(exception)
    render json: { error: exception.message }, status: 422
  end

  def record_not_found
    render json: 'Record not found', status: 404
  end
end
