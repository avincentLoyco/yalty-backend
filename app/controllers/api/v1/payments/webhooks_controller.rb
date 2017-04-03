module API
  module V1
    module Payments
      class WebhooksController < ::ApplicationController
        protect_from_forgery except: :webhook
        before_action :request_authentication

        def webhook
          ::Payments::StripeEventsHandler.perform_later(params[:id])
          head 200
        end

        private

        def request_authentication
          authenticate_or_request_with_http_basic do |_, password|
            password == ENV['STRIPE_WEBHOOK_PASSWORD']
          end
        end
      end
    end
  end
end
