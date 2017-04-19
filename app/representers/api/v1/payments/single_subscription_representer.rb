module Api
  module V1
    module Payments
      class SingleSubscriptionRepresenter < Api::V1::BaseRepresenter
        def complete
          {
            id: resource.id,
            tax_percent: resource.tax_percent,
            current_period_end: current_period_end,
            quantity: Account.current.employees.active_at_date(current_period_end).count
          }
        end

        private

        def current_period_end
          Time.zone.at(resource.current_period_end)
        end
      end
    end
  end
end
