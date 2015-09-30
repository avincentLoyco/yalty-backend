module API
  module V1
    class EmployeeResource < JSONAPI::Resource
      has_many :employee_attributes, class_name: 'EmployeeAttribute'
      has_many :events, class_name: 'EmployeeEvent'
      has_one :working_place, class_name: 'WorkingPlace'

      def self.records(_options = {})
        Account.current.employees
      end
    end
  end
end
