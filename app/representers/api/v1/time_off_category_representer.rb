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
      current_employee = Account::User.current.employee
      return unless current_employee.present?
      EmployeeTimeOffPolicy.by_employee_in_category(current_employee.id, resource.id)
                           .try(:last).try(:effective_at)
    end
  end
end
