module Api::V1
  class EmployeeRepresenter < BaseRepresenter
    def complete
      {
        already_hired: hire_status
      }
        .merge(basic)
        .merge(relationships)
    end

    def relationships
      {
        employee_attributes: employee_attributes_json,
        working_place: working_place_json
      }
    end

    def employee_attributes_json
      employee_attributes.map do |attribute|
        EmployeeAttributeRepresenter.new(attribute).complete
      end
    end

    def working_place_json
      return {} unless active_employee_working_place.present?
      EmployeeWorkingPlaceRepresenter.new(active_employee_working_place).working_place_json
    end

    def employee_attributes
      attributes = resource.employee_attributes
      return attributes if attributes.present?
      resource.events.first.try(:employee_attribute_versions).to_a
    end

    def hire_status
      hire_event = resource.events.where(event_type: 'hired').last.try(:effective_at)
      hire_event <= Time.zone.today if hire_event
    end

    def active_employee_working_place
      @active_employee_working_place ||=
        related_resources(EmployeeWorkingPlace, nil, resource.id).first
    end
  end
end
