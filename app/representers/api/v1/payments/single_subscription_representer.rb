module Api
  module V1
    module Payments
      class SingleSubscriptionRepresenter < Api::V1::BaseRepresenter
        def complete
          {
            id: resource.id,
            current_period_end: Time.zone.at(resource.current_period_end),
            quantity: resource.quantity
          }
        end
      end
    end
  end
end
