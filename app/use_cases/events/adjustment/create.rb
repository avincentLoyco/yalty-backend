# TODO: refactor this class to use dependency injection

module Events
  module Adjustment
    class Create < Default::Create
      config_accessor :balance_handler do
        CreateEmployeeBalance
      end

      def call
        ActiveRecord::Base.transaction do
          event.tap do
            handle_adjustment
          end
        end
      end

      private

      def handle_adjustment
        balance_handler.call(
          event.account.vacation_category.id,
          event.employee_id,
          event.account.id,
          balance_type: "manual_adjustment",
          resource_amount: event.attribute_value("adjustment"),
          manual_amount: 0,
          effective_at: event.effective_at + Employee::Balance::MANUAL_ADJUSTMENT_OFFSET
        )
      end
    end
  end
end
