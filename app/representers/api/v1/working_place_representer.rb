module Api::V1
  class WorkingPlaceRepresenter < BaseRepresenter
    def complete
      {
        name: resource.name,
        street: resource.street,
        street_number: resource.street_number,
        additional_address: resource.additional_address,
        city: resource.city,
        postalcode: resource.postalcode,
        state: resource.state,
        state_code: resource.state_code,
        country: resource.country,
        country_code: resource.country_code,
        timezone: resource.timezone,
        deletable: assigned_employees_json.empty?,
      }
        .merge(basic)
        .merge(relationships)
    end

    def relationships
      {
        employees: assigned_employees_json,
      }
    end

    def assigned_employees_json
      related_resources(EmployeeWorkingPlace, resource.id).map do |employee_working_place|
        EmployeeWorkingPlaceRepresenter.new(employee_working_place).complete
      end
    end
  end
end
