module Events
  module ContractEnd
    class AssignEmployeeTopToEvent
      include AppDependencies[
        find_vacation_category: "use_cases.time_off_categories.find_by_name",
      ]

      def call(event)
        event.employee_time_off_policy = event.employee.assigned_time_off_policies_in_category(
          vacation_time_off_category_id, event.effective_at
        ).order(:effective_at).last
        event.save!
      end

      private

      def vacation_time_off_category_id
        find_vacation_category.call("vacation").id
      end
    end
  end
end
