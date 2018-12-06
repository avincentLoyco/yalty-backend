module Events
  module ContractEnd
    class Create < Default::Create
      include AppDependencies[
        assign_employee_top_to_event: "use_cases.events.contract_end.assign_employee_top_to_event",
        contract_end_service: "services.event.contract_ends.create",
      ]

      def call(params)
        ActiveRecord::Base.transaction do
          super.tap do |event|
            assign_employee_top_to_event.call(event)
            handle_contract_end
          end
        end
      end

      private

      def handle_contract_end
        contract_end_service.call(
          employee: event.employee,
          contract_end_date: event.effective_at,
          eoc_event_id: event.id,
        )
      end
    end
  end
end
