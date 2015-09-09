module API
  module V1
    class EmployeeAttributeResource < JSONAPI::Resource
      model_name 'Employee::Attribute'
      attributes :attribute_name, :attribute_type, :value, :effective_at

      has_one :attribute_definition, class_name: 'EmployeeAttributeDefinition'
      has_one :event, class_name: 'EmployeeEvent', foreign_key: 'employee_event_id'

      def value
        value = model.data.to_hash.dup
        value.delete('attribute_type')

        if value.keys.size > 1
          value
        else
          value.values.first
        end
      end
    end
  end
end
