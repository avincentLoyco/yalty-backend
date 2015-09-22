module API
  module V1
    class EmployeeAttributeResource < JSONAPI::Resource
      model_name 'Employee::Attribute'
      attributes :attribute_name, :attribute_type, :value, :effective_at

      has_one :attribute_definition, class_name: 'EmployeeAttributeDefinition'
      has_one :event, class_name: 'EmployeeEvent', foreign_key: 'employee_event_id'

      def self.records(options = {})
        Employee::AttributeVersion.joins(:account).where(accounts: {id: Account.current.id })
      end
    end
  end
end
