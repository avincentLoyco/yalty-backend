module Api::V1
  class WorkingPlaceRepresenter < BaseRepresenter
    def complete
      {
        name: resource.name,
        deletable: assigned_employees_json.empty?
      }
        .merge(basic)
        .merge(relationships)
    end

    def relationships
      {
        holiday_policy: holiday_policy_json,
        employees: assigned_employees_json
      }
    end

    def holiday_policy_json
      HolidayPolicyRepresenter.new(resource.holiday_policy).basic
    end

    def assigned_employees_json
      related_resources(EmployeeWorkingPlace, resource.id).map do |employee_working_place|
        EmployeeWorkingPlaceRepresenter.new(employee_working_place).complete
      end
    end
  end
end
