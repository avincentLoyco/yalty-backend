module Events
  module ContractEnd
    class Update
      include AppDependencies[
        assign_employee_top_to_event: "use_cases.events.contract_end.assign_employee_top_to_event",
        update_event_service: "services.event.update_event",
      ]

      def call(event, params)
        ActiveRecord::Base.transaction do
          assign_employee_top_to_event.call(event)
          update_event_service.new(event, params).call
        end
      end
    end
  end
end
