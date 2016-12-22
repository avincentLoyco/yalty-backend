module Api::V1
  class TimeOffCategoryRepresenter < BaseRepresenter
    def complete
      {
        name: resource.name,
        system: resource.system,
        first_assignation_date: find_first_assignation_date
      }
        .merge(basic)
    end

    def find_first_assignation_date
      current_employee = current_user.employee
      return unless current_employee

      EmployeeTimeOffPolicy.by_employee_in_category(current_employee.id, resource.id)
                           .last.pluck(:effective_at)
    end
  end
end
