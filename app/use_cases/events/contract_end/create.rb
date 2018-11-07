module Events
  module ContractEnd
    class Create
      include AppDependencies[
        assign_employee_top_to_event: "use_cases.events.contract_end.assign_employee_top_to_event",
        contract_end_service: "services.event.contract_ends.create",
        create_event_service: "services.event.create_event",
      ]

      def call(params)
        ActiveRecord::Base.transaction do
          create_event(params).tap do |event|
            assign_employee_top_to_event.call(event)
            handle_contract_end(event)
          end
        end
      end

      private

      def create_event(params)
        create_event_service.new(params, params[:employee_attributes].to_a).call
      end

      def handle_contract_end(event)
        contract_end_service.call(
          employee: event.employee,
          contract_end_date: event.effective_at,
          event_id: event.id,
        )
      end
    end
  end
end
