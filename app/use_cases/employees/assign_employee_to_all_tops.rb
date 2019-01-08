# frozen_string_literal: true

module Employees
  class AssignEmployeeToAllTops
    include AppDependencies[
      etop_model: "models.employee_time_off_policy",
      find_unassigned_tops_for_employee: "use_cases.employees.find_unassigned_tops_for_employee"
    ]

    def call(employee)
      unassigned_tops = find_unassigned_tops_for_employee.call(employee)

      # TODO: move the db call to a command
      etop_model.create!(
        etops_to_create(employee.id, unassigned_tops)
      )
    end

    private

    def etops_to_create(employee_id, unassigned_tops)
      unassigned_tops.map do |top|
        {
          employee_id: employee_id,
          time_off_policy_id: top.id,
          time_off_category_id: top.time_off_category_id,
          effective_at: current_time,
        }
      end
    end

    def current_time
      @current_time ||= Time.current
    end
  end
end
