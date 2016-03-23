module Api::V1
  class PublicEmployeeRepresenter < BaseRepresenter
    def complete
      basic.merge(relationships)
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
      return attributes.try(:visible_for_other_employees) if attributes.present?
      resource.events.first
              .try(:employee_attribute_versions)
              .try(:visible_for_other_employees).to_a
    end
  end
end
