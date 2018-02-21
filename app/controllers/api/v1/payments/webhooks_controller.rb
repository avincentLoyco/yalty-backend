module API
  module V1
    module Payments
      class WebhooksController < ::ApplicationController
        protect_from_forgery except: :webhook
        before_action :request_authentication

        def webhook
          remove_canceled_plans
          ::Payments::StripeEventsHandler.perform_later(params[:id])
          head 200
        end

        private

        def remove_canceled_plans
          return unless params[:type].eql?("invoice.created")

          account = Account.find_by!(customer_id: params[:data][:object][:customer])
          canceled_or_free = account.available_modules.canceled_or_free
          return unless canceled_or_free.any? && event.data.object.customer == account.customer_id

          Stripe::SubscriptionItem.list(subscription: account.subscription_id).each do |item|
            item.delete if canceled_or_free.include?(item.plan.id)
          end
        end

        def request_authentication
          authenticate_or_request_with_http_basic do |_, password|
            password == ENV["STRIPE_WEBHOOK_PASSWORD"]
          end
        end

        def stripe_error(_message)
          head 502
        end

        def event
          @event ||= Stripe::Event.retrieve(params[:id])
        end
      end
    end
  end
end
