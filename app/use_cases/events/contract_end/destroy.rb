module Events
  module ContractEnd
    class Destroy
      include AppDependencies[
        find_and_destroy_eoc_balance: "use_cases.balances.end_of_contract.find_and_destroy",
        delete_event_service: "services.event.delete_event"
      ]

      def call(event)
        ActiveRecord::Base.transaction do
          find_and_destroy_eoc_balance.call(employee: event.employee, eoc_date: event.effective_at)
          unassign_employee_time_off_policy_from_event(event)
          delete_event_service.new(event).call
        end
      end

      private

      def unassign_employee_time_off_policy_from_event(event)
        event.employee_time_off_policy = nil
        event.save!
      end
    end
  end
end
