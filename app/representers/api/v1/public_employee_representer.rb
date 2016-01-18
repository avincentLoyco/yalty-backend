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
  end
end
