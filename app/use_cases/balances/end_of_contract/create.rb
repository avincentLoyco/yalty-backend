module Balances
  module EndOfContract
    class Create
      include AppDependencies[
        create_employee_balance_service: "services.employee_balance.create_employee_balance",
        find_effective_at: "use_cases.balances.end_of_contract.find_effective_at"
      ]

      def call(employee:, eoc_event_id:, contract_end_date:)
        @employee = employee
        @eoc_event_id = eoc_event_id
        @contract_end_date = contract_end_date

        # NOTE: Most probably there should always be at least one vacation balance for an employee.
        # This check was added to handle random situations and to avoid fixing a lot of controller
        # specs
        return unless effective_at

        create_employee_balance
      end

      private

      attr_reader :employee, :eoc_event_id, :contract_end_date

      def create_employee_balance
        create_employee_balance_service.new(
          vacation_toc.id,
          employee.id,
          employee.account.id,
          balance_type: "end_of_contract",
          effective_at: effective_at,
          skip_update: true,
          event_id: eoc_event_id
        ).call
      end

      def vacation_toc
        @vacation_toc ||= employee.account.time_off_categories.find_by(name: "vacation")
      end

      def effective_at
        @effective_at ||= find_effective_at.call(
          employee: employee,
          vacation_toc_id: vacation_toc.id,
          contract_end_date: contract_end_date
        )
      end
    end
  end
end
