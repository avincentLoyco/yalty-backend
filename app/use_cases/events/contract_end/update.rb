module Events
  module ContractEnd
    class Update < Default::Update
      include AppDependencies[
        assign_employee_top_to_event: "use_cases.events.contract_end.assign_employee_top_to_event",
      ]

      def call(event, params)
        ActiveRecord::Base.transaction do
          assign_employee_top_to_event.call(event)
          super
        end
      end
    end
  end
end
