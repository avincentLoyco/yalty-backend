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
          single_subscription_json.merge(
            plans: plans_json,
            invoice: invoice_json,
            billing_information: billing_information
          )
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

        def billing_information
          {
            company_information: {
              company_name: @account.invoice_company_info.company_name,
              additional_address: @account.invoice_company_info.additional_address,
              street: @account.invoice_company_info.street,
              city: @account.invoice_company_info.city,
              country: @account.invoice_company_info.country,
              postalcode: @account.invoice_company_info.postalcode,
              region: @account.invoice_company_info.region
            },
            emails: @account.invoice_emails
          }
        end
      end
    end
  end
end
