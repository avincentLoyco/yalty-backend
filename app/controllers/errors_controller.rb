class ErrorsController < ApplicationController
  def routing_error
    raise ActionController::RoutingError.new(params[:path])
  end
end
