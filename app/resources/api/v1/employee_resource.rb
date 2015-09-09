module API
  module V1
    class EmployeeResource < JSONAPI::Resource
      has_many :employee_attributes, class_name: 'EmployeeAttribute'
      has_many :events, class_name: 'EmployeeEvent'

      def self.records(options = {})
        Account.current.employees
      end
    end
  end
end
