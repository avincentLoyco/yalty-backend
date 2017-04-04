module Api
  module V1
    module Payments
      class LineItemRepresenter < Api::V1::BaseRepresenter
        def complete
          {
            id: resource.id,
            amount: resource.amount,
            currency: resource.currency,
            period_start: period_start,
            period_end: period_end,
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
          return unless resource.plan.present?
          ::Api::V1::Payments::PlanRepresenter.new(resource.plan).complete
        end

        def period_start
          if resource.respond_to?(:period)
            Time.zone.at(resource.period.start)
          else
            resource.period_start
          end
        end

        def period_end
          if resource.respond_to?(:period)
            Time.zone.at(resource.period.end)
          else
            resource.period_end
          end
        end
      end
    end
  end
end
