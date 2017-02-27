module Api
  module V1
    module Payments
      class SubscriptionsRepresenter < Api::V1::BaseRepresenter
        def initialize(subscription, plans, invoice, account)
          @subscription = subscription
          @plans = plans
          @invoice = invoice
          @account = account
        end

        def complete
          single_subscription_json.merge(plans: plans_json, invoice: invoice_json)
        end

        private

        def single_subscription_json
          ::Api::V1::Payments::SingleSubscriptionRepresenter.new(@subscription).complete
        end

        def plans_json
          @plans.map { |plan| ::Api::V1::Payments::PlanRepresenter.new(plan).complete }
        end

        def invoice_json
          ::Api::V1::Payments::InvoiceRepresenter.new(@invoice).complete
        end
      end
    end
  end
end
