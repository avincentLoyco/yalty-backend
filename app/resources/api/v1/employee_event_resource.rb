module API
  module V1
    class EmployeeEventResource < JSONAPI::Resource
      model_name 'Employee::Event'

      attributes :effective_at, :event_type, :comment

      has_one :employee
      has_many :employee_attributes, relation_name: :employee_attribute_versions

      def self.records(options = {})
        Account.current.employee_events
      end
    end
  end
end
