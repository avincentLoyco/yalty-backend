module Api::V1
  class UserRepresenter < BaseRepresenter
    def complete
      {
        email:           resource.email,
        locale:          resource.locale,
        role:            resource.role,
        is_employee:     resource.employee.present?,
        referral_token:  resource.referrer.try(:token)
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
