module Api
  module V1
    module Payments
      class LineItemRepresenter < Api::V1::BaseRepresenter
        def complete
          {
            id: resource.id,
            amount: resource.amount,
            currency: resource.currency,
            period_start: Time.zone.at(resource.period.start),
            period_end: Time.zone.at(resource.period.end),
            proration: resource.proration,
            quantity: resource.quantity,
            subscription: resource.subscription,
            subscription_item: resource.subscription_item,
            type: resource.type,
            plan: plan
          }
        end

        private

        def plan
          return unless plan.present?
          ::Api::V1::Payments::PlanRepresenter.new(resource.plan).complete
        end
      end
    end
  end
end
