module Api
  module V1
    module Payments
      class SubscriptionsRepresenter < Api::V1::BaseRepresenter
        def initialize(subscription, plans, invoice, default_card, account)
          @subscription = subscription
          @plans = plans
          @invoice = invoice
          @default_card = default_card
          @account = account
        end

        def complete
          single_subscription_json.merge(
            plans: plans_json,
            invoice: invoice_json,
            default_card: default_card_json,
            billing_information: billing_information_json
          )
        end

        private

        def single_subscription_json
          return {} unless @subscription.present?
          ::Api::V1::Payments::SingleSubscriptionRepresenter.new(@subscription).complete
        end

        def plans_json
          return [] unless @plans.present?
          @plans.map { |plan| ::Api::V1::Payments::PlanRepresenter.new(plan).complete }
        end

        def invoice_json
          return unless @invoice.present?
          ::Api::V1::Payments::InvoiceRepresenter.new(@invoice).next_invoice
        end

        def default_card_json
          return unless @default_card.present?
          ::Api::V1::Payments::CardRepresenter.new(@default_card).complete
        end

        def billing_information_json
          {
            company_information: {
              company_name: @account.company_information.company_name,
              address_1: @account.company_information.address_1,
              address_2: @account.company_information.address_2,
              city: @account.company_information.city,
              country: @account.company_information.country,
              postalcode: @account.company_information.postalcode,
              region: @account.company_information.region,
              phone: @account.company_information.phone,
            },
            emails: @account.invoice_emails,
          }
        end
      end
    end
  end
end
