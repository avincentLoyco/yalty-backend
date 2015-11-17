class ErrorsController < ApplicationController
  def routing_error
    fail ActionController::RoutingError.new(params[:path])
  end
end
