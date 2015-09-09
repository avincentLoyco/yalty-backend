module API
  module V1
    class EmployeeResource < JSONAPI::Resource
      has_many :employee_attributes, class_name: 'Employees::Attribute'

      def self.records(options = {})
        Account.current.employees
      end
    end
  end
end
