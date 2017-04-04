module Api
  module V1
    module Payments
      class PlanRepresenter < Api::V1::BaseRepresenter
        def complete
          {
            id: resource.id,
            amount: resource.amount,
            currency: resource.currency,
            interval: resource.interval,
            name: resource.name,
            active: resource.active
          }
        end
      end
    end
  end
end
