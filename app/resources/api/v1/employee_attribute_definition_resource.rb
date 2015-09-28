module API
  module V1
    class EmployeeAttributeDefinitionResource < JSONAPI::Resource
      model_name 'Employee::AttributeDefinition'

      attributes :name, :label, :attribute_type, :system

      def self.records(_options = {})
        Account.current.employee_attribute_definitions
      end
    end
  end
end
