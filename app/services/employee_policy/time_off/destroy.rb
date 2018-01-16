module EmployeePolicy
  module TimeOff
    class Destroy
      attr_reader :employee_time_off_policy, :employee, :time_off_category, :effective_at

      def self.call(employee_time_off_policy)
        new(employee_time_off_policy).call
      end

      def initialize(employee_time_off_policy)
        return unless employee_time_off_policy
        @employee_time_off_policy = employee_time_off_policy
        @employee                 = employee_time_off_policy.employee
        @time_off_category        = employee_time_off_policy.time_off_category
        @effective_at             = employee_time_off_policy.effective_at
      end

      def call
        return unless employee_time_off_policy
        employee_time_off_policy.delete
        ClearResetJoinTables.call(employee, effective_at, time_off_category, nil)
        RecreateBalances::AfterEmployeeTimeOffPolicyDestroy.call(
          destroyed_effective_at: effective_at,
          time_off_category_id: time_off_category.id,
          employee_id: employee.id
        )
      end
    end
  end
end
