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
        employee: employee,
        employee_attributes: attribute_versions
      }
    end

    def attribute_versions
      attribute_versions = select_attributes
      attribute_versions.map do |attribute|
        EmployeeAttributeVersionRepresenter.new(attribute).complete
      end
    end

    def select_attributes
      if current_user.try(:employee).try(:id) == resource.employee_id ||
          current_user.try(:account_manager)
        resource.employee_attribute_versions
      else
        resource.employee_attribute_versions.visible_for_other_employees
      end
    end
  end
end
