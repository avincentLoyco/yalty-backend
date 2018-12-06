module Events
  module ContractEnd
    class Destroy < Default::Destroy
      include AppDependencies[
        find_and_destroy_eoc_balance: "use_cases.balances.end_of_contract.find_and_destroy",
      ]

      def call(event)
        @event = event

        ActiveRecord::Base.transaction do
          find_and_destroy_eoc_balance.call(
            employee: event.employee, eoc_date: event.effective_at
          )
          unassign_employee_time_off_policy_from_event
          super
        end
      end

      private

      def unassign_employee_time_off_policy_from_event
        event.employee_time_off_policy = nil
        event.save!
      end
    end
  end
end
