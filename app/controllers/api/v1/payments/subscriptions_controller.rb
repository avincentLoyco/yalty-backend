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

        def subscription_json
          ::Api::V1::Payments::SubscriptionsRepresenter.new(
            subscription,
            plans,
            upcoming_invoice,
            default_card,
            Account.current
          ).complete
        end

        def upcoming_invoice
          Stripe::Invoice.upcoming(customer: Account.current.customer_id)
        end

        def plans
          Stripe::Plan.list.select do |plan|
            next if plan.id.eql?('free-plan')
            plan.active = subscription_plans.include?(plan.id)
            plan
          end
        end

        def subscription_plans
          @subscription_plans ||= subscription.items.map { |si| si.plan.id }
        end

        def subscription
          @subscription ||= Stripe::Subscription.retrieve(Account.current.subscription_id)
        end

        def update_company_info!(attributes)
          return unless attributes.key?(:company_information)
          Account.current.update!(invoice_company_info: attributes[:company_information])
        end

        def update_invoice_emails!(attributes)
          return unless attributes.key?(:emails)
          Account.current.update!(invoice_emails: attributes[:emails])
        end

        def default_card
          customer.sources.find { |src| src.default = src.id.eql?(customer.default_source) }
        end
      end
    end
  end
end
