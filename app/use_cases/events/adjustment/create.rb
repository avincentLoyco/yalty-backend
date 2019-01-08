module Events
  module Adjustment
    class Create < Default::Create
      include EndOfContractHandler # eoc_event, destroy_eoc_balance, recreate_eoc_balance
      include AppDependencies[
        create_employee_balance_service: "services.employee_balance.create_employee_balance",
        find_and_destroy_eoc_balance: "use_cases.balances.end_of_contract.find_and_destroy",
        create_eoc_balance: "use_cases.balances.end_of_contract.create",
        find_first_eoc_event_after: "use_cases.events.contract_end.find_first_after_date",
      ]

      def call(params)
        ActiveRecord::Base.transaction do
          super.tap do |created_event|
            destroy_eoc_balance if eoc_event
            create_manual_adjustment_balance
            return created_event unless eoc_event
            recreate_eoc_balance
          end
        end
      end

      private

      def create_manual_adjustment_balance
        create_employee_balance_service.call(
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
