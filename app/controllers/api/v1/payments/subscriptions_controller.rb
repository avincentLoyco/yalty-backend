module API
  module V1
    module Payments
      class SubscriptionsController < ApplicationController
        include PaymentsHelper

        def index
          render json: subscription_json
        end

        private

        def upcoming_invoice
          Stripe::Invoice.upcoming(customer: Account.current.customer_id)
        end

        def subscription
          Stripe::Subscription.retrieve(Account.current.subscription_id)
        end

        def plans
          Stripe::Plan.list.data.map do |plan|
            plan.active = false
            active_plans.find { |active_plan| active_plan.id.eql?(plan.id) } || plan
          end
        end

        def active_plans
          @active_plans ||= Stripe::SubscriptionItem
            .list(subscription: Account.current.subscription_id)
            .data
            .map do |subscription_item|
              plan = subscription_item.plan
              plan.active = true
              plan
            end
        end

        def subscription_json
          ::Api::V1::Payments::SubscriptionsRepresenter.new(
            subscription,
            plans,
            upcoming_invoice,
            Account.current
          ).complete
        end
      end
    end
  end
end
