module Api::V1
  class WorkingPlaceRepresenter < BaseRepresenter
    def complete
      {
        name: resource.name,
        country: resource.country,
        city: resource.city,
        state: resource.state,
        postalcode: resource.postalcode,
        street: resource.street,
        street_number: resource.street_number,
        additional_address: resource.additional_address,
        timezone: resource.timezone,
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
