module API
  module V1
    module Employees
      class AttributeDefinitionResource < JSONAPI::Resource
        model_name 'Employee::AttributeDefinition'

        attributes :name, :label, :attribute_type, :system

        def self.records(options = {})
          Account.current.employee_attribute_definitions
        end
      end
    end
  end
end
