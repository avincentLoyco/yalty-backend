module Api::V1
  class EmployeeEventRepresenter < BaseRepresenter
    def complete
      {
        effective_at: resource.effective_at,
        comment: resource.comment,
        event_type: resource.event_type
      }
        .merge(basic)
        .merge(relationship)
    end

    def relationship
      employee = EmployeeRepresenter.new(resource.employee).basic
      {
        employee: employee.merge(attribute_versions)
      }
    end

    def attribute_versions
      response = resource.employee_attribute_versions.map do |attribute|
        EmployeeAttributeVersionRepresenter.new(attribute).complete
      end
      {
        employee_attributes: response
      }
    end
  end
end
