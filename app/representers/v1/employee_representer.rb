module V1
  class EmployeeRepresenter < BaseRepresenter
    def complete
      basic.merge(relationships)
    end

    def relationships
      response = resource.employee_attributes.map do |attribute|
        EmployeeAttributeRepresenter.new(attribute).complete
      end
      {
        employee_attributes: response
      }
    end
  end
end
