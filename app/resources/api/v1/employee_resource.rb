module API
  module V1
    class EmployeeResource < JSONAPI::Resource
      has_many :employee_attributes, class_name: 'EmployeeAttribute'
      has_many :events, class_name: 'EmployeeEvent'
      has_one :working_place, class_name: 'WorkingPlace'
      has_one :holiday_policy, class_name: 'HolidayPolicy'
      attributes :account

      def self.records(_options = {})
        Account.current.employees
      end

      def record_for_holiday_policy
        policy_id = holiday_policy_id || working_place.holiday_policy_id || account.holiday_policy_id
        HolidayPolicy.find(policy_id)
      end
    end
  end
end
