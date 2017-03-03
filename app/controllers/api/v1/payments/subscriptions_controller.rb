module API
  module V1
    module Payments
      class SubscriptionsController < ApplicationController
        include SubscriptionsSchemas
        include PaymentsHelper

        def index
          render json: subscription_json
        end

        def settings
          verified_dry_params(settings_schema) do |attributes|
            Account.transaction do
              update_company_info!(attributes)
              update_invoice_emails!(attributes)
            end
            render_no_content
          end
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

        def update_company_info!(attributes)
          return unless attributes.key?(:company_information)
          Account.current.update!(invoice_company_info: attributes[:company_information])
        end

        def update_invoice_emails!(attributes)
          return unless attributes.key?(:emails)
          Account.current.update!(invoice_emails: attributes[:emails])
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
