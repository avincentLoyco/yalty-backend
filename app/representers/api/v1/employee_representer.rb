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
        employee_attributes: employee_attributes_json
      }
    end

    def employee_attributes_json
      employee_attributes.map do |attribute|
        EmployeeAttributeRepresenter.new(attribute).complete
      end
    end

    def employee_attributes
      attributes = resource.employee_attributes
      return attributes if attributes.present?
      resource.events.first.try(:employee_attribute_versions).to_a
    end

    def hire_status
      hire_event = resource.events.where(event_type: 'hired').last.try(:effective_at)
      hire_event <= Time.zone.now if hire_event
    end
  end
end
