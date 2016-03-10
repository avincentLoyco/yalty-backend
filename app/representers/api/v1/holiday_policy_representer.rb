module Api::V1
  class HolidayPolicyRepresenter < BaseRepresenter
    def complete
      {
        name: resource.name,
        country: resource.country,
        region: resource.region
      }
        .merge(basic)
        .merge(relationships)
    end

    def relationships
      {
        working_places: working_places_json,
        employees: employees_json
      }
    end

    def working_places_json
      resource.working_places.map do |working_place|
        WorkingPlaceRepresenter.new(working_place).basic
      end
    end

    def employees_json
      resource.employees.map do |employee|
        EmployeeRepresenter.new(employee).basic
      end
    end
  end
end
