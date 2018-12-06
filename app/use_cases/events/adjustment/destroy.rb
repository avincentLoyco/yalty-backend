module Events
  module Adjustment
    class Destroy < Default::Destroy
      include EndOfContractHandler # eoc_event, destroy_eoc_balance, recreate_eoc_balance
      include AppDependencies[
        destroy_employee_balance_service: "services.employee_balance.destroy_employee_balance",
        find_adjustment_balance: "use_cases.events.adjustment.find_adjustment_balance",
        find_and_destroy_eoc_balance: "use_cases.balances.end_of_contract.find_and_destroy",
        create_eoc_balance: "use_cases.balances.end_of_contract.create",
        find_first_eoc_event_after: "use_cases.events.contract_end.find_first_after_date",
      ]

      def call(event)
        @event = event

        ActiveRecord::Base.transaction do
          destroy_eoc_balance if eoc_event
          super
          destroy_employee_balance_service.call(adjustment_balance)
          return event unless eoc_event
          recreate_eoc_balance
          event
        end
      end

      private

      attr_reader :event

      def adjustment_balance
        @adjustment_balance ||= find_adjustment_balance.call(event)
      end
    end
  end
end
