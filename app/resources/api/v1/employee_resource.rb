module API
  module V1
    class EmployeeResource < JSONAPI::Resource
      has_many :employee_attributes

      def self.records(options = {})
        Account.current.employees
      end
    end
  end
end
