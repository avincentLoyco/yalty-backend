module Api::V1
  class UserRepresenter < BaseRepresenter
    def complete
      {
        email:           resource.email,
        account_manager: resource.account_manager,
        is_employee:        resource.employee.present?
      }
        .merge(basic)
        .merge(relationships)
    end

    def relationships
      {
        employee: employee_json
      }
    end

    def employee_json
      EmployeeRepresenter.new(resource.employee).basic
    end
  end
end
