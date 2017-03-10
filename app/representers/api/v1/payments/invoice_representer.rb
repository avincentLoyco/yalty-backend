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
            line_items: line_items_json
          }
        end

        private

        def prorate_amount
          resource.lines.inject(0) do |sum, item|
            sum += item.amount if item.proration
            sum
          end
        end

        def line_items_json
          line_items.map do |line_item|
            ::Api::V1::Payments::LineItemRepresenter.new(line_item).complete
          end
        end

        def line_items
          resource.lines.select do |line|
            next if line.plan.present? && line.plan.id.eql?('free-plan')
            line.plan.active = active_plan_ids.include?(line.plan.id) if line.plan.present?
            line
          end
        end

        def active_plan_ids
          @active_plan_ids ||= Account.current.available_modules
        end
      end
    end
  end
end
