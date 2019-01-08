module Events
  module Adjustment
    class FindAdjustmentBalance
      include AppDependencies[
        employee_balance_model: "models.employee.balance",
      ]

      def call(event)
        @event = event
        employee_balance_model.find_by!(
          time_off_category_id: time_off_category_id,
          employee_id: event.employee_id,
          effective_at: event.effective_at + Employee::Balance::MANUAL_ADJUSTMENT_OFFSET
        )
      end

      private

      attr_reader :event

      def time_off_category_id
        event.account.vacation_category.id
      end
    end
  end
end
