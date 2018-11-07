module Balances
  module EndOfContract
    class Create
      include AppDependencies[
        create_employee_balance_service: "services.employee_balance.create_employee_balance"
      ]

      def call(employee:, vacation_toc_id:, effective_at:, event_id:)
        create_employee_balance_service.new(
          vacation_toc_id,
          employee.id,
          employee.account.id,
          balance_type: "end_of_contract",
          effective_at: effective_at,
          skip_update: true,
          event_id: event_id
        ).call
      end
    end
  end
end
