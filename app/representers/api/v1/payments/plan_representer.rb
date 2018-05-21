module Api
  module V1
    module Payments
      class PlanRepresenter < Api::V1::BaseRepresenter
        def complete
          {
            id: resource.id,
            name: resource.try(:name) || resource.id.titleize,
            amount: resource.amount,
            currency: resource.currency,
            interval: resource.interval,
            active: resource.active,
            free: resource.free,
          }
        end
      end
    end
  end
end
