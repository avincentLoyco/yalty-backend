module Api::V1
  class UserRepresenter < BaseRepresenter
    def complete
      {
        email:           resource.email,
        account_manager: resource.account_manager,
        is_employee:        resource.employee.present?
      }
        .merge(basic)
        .merge(employee)
    end

    def employee
      return {} if resource.employee.blank?

      Api::V1::EmployeeRepresenter.new(resource.employee).basic
    end

  end
end
