module Events
  module Adjustment
    class Update < Default::Update
      include EndOfContractHandler # eoc_event, destroy_eoc_balance, recreate_eoc_balance
      include AppDependencies[
        find_adjustment_balance: "use_cases.events.adjustment.find_adjustment_balance",
        update_next_employee_balances_service:
          "services.employee_balance.update_next_employee_balances",
        find_and_destroy_eoc_balance: "use_cases.balances.end_of_contract.find_and_destroy",
        create_eoc_balance: "use_cases.balances.end_of_contract.create",
        find_first_eoc_event_after: "use_cases.events.contract_end.find_first_after_date",
      ]

      def call(event, params)
        @event = event
        @params = params

        adjustment_balance # Get adjustment_balance before event's effective_at is updated

        ActiveRecord::Base.transaction do
          destroy_eoc_balance if eoc_event

          super.tap do |updated_event|
            adjustment_balance.update!(
              resource_amount: updated_event.attribute_value("adjustment"),
              effective_at: updated_event.effective_at + Employee::Balance::MANUAL_ADJUSTMENT_OFFSET
            )
            update_next_employee_balances_service.new(adjustment_balance).call
            return updated_event unless eoc_event
            recreate_eoc_balance
          end
        end
      end

      private

      def adjustment_balance
        @adjustment_balance ||= find_adjustment_balance.call(event)
      end
    end
  end
end
