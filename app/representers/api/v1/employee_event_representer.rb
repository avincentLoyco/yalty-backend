module Api::V1
  class EmployeeEventRepresenter < BaseRepresenter
    def complete
      {
        effective_at: resource.effective_at,
        event_type: resource.event_type
      }
        .merge(basic)
        .merge(relationship)
    end

    def relationship
      {
        employee: employee_json,
        employee_attributes: attribute_versions
      }
    end

    def employee_json
      EmployeeRepresenter.new(resource.employee).basic
    end

    def attribute_versions
      attribute_versions = select_attributes
      attribute_versions.map do |attribute|
        EmployeeAttributeVersionRepresenter.new(attribute).complete
      end
    end

    def select_attributes
      if Account::User.current.try(:owner_or_administrator?) ||
          Account::User.current.try(:employee).try(:id) == resource.employee_id
        resource.employee_attribute_versions
      else
        resource.employee_attribute_versions.visible_for_other_employees
      end
    end
  end
end
