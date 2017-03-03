module Api
  module V1
    module Payments
      class InvoiceRepresenter < Api::V1::BaseRepresenter
        def complete
          {
            id: resource.try(:id),
            amount_due: resource.amount_due,
            date: Time.zone.at(resource.date),
            prorate_amount: prorate_amount,
            line_items: line_items
          }
        end

        private

        def prorate_amount
          resource.lines.inject(0) do |sum, item|
            sum += item.amount if item.proration
            sum
          end
        end

        def line_items
          resource.lines.map do |line_item|
            ::Api::V1::Payments::LineItemRepresenter.new(line_item).complete
          end
        end
      end
    end
  end
end
