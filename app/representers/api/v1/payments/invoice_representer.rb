module Api
  module V1
    module Payments
      class InvoiceRepresenter < Api::V1::BaseRepresenter
        def complete
          basic_json.merge(
            line_items: line_items_json,
            prorate_amount: prorate_amount,
            file_id: resource.generic_file&.id
          )
        end

        def next_invoice
          basic_json.merge(
            line_items: line_items_json(omit_canceled: true),
            prorate_amount: prorate_amount(omit_canceled: true)
          )
        end

        private

        def basic_json
          {
            id: resource.try(:id),
            amount_due: resource.amount_due,
            date: resource.date.is_a?(Integer) ? Time.zone.at(resource.date) : resource.date,
            receipt_number: resource.receipt_number,
            starting_balance: resource.starting_balance,
            subtotal: resource.subtotal,
            tax: resource.tax,
            tax_percent: resource.tax_percent&.to_f,
            total: resource.total,
          }
        end

        def prorate_amount(omit_canceled: false)
          filtered_line_items(omit_canceled).inject(0) do |sum, item|
            sum += item.amount if item.proration
            sum
          end
        end

        def line_items_json(omit_canceled: false)
          filtered_line_items(omit_canceled).map do |line_item|
            ::Api::V1::Payments::LineItemRepresenter.new(line_item).complete
          end
        end

        def filtered_line_items(omit_canceled)
          resource.lines.data.map do |line|
            next if line.plan.present? &&
                line.plan.id.eql?("free-plan") ||
                (omit_canceled && canceled_modules.include?(line.plan.id))

            line.plan.active = active_modules.include?(line.plan.id) if line.plan.present?
            line.plan.free = free_modules.include?(line.plan.id) if line.plan.present?
            line
          end.compact
        end

        def active_modules
          @active_modules ||= Account.current.available_modules.all
        end

        def canceled_modules
          @canceled_modules ||= Account.current.available_modules.canceled
        end

        def free_modules
          @free_modules ||= Account.current.available_modules.free
        end
      end
    end
  end
end
