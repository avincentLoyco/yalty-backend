module Api::V1
  class PresencePolicyRepresenter < BaseRepresenter
    def complete
      {
        name: resource.name
      }
        .merge(basic)
    end

    def with_relationships
      complete.merge(presence_days: presence_days_json)
              .merge(employees: employees_json)
              .merge(working_places: working_places_json)
    end

    def presence_days_json
      resource.presence_days.map do |attribute|
        PresenceDayRepresenter.new(attribute).complete
      end
    end

    def employees_json
      resource.employees.map do |attribute|
        EmployeeRepresenter.new(attribute).basic
      end
    end

    def working_places_json
      resource.working_places.map do |attribute|
        WorkingPlaceRepresenter.new(attribute).basic
      end
    end
  end
end
