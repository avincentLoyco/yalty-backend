module EmployeePolicy
  module Presence
    class Destroy
      attr_reader :employee_presence_policy, :effective_at

      def self.call(employee_presence_policy)
        new(employee_presence_policy).call
      end

      def initialize(employee_presence_policy)
        @employee_presence_policy = employee_presence_policy
        @effective_at             = employee_presence_policy.effective_at
      end

      def call
        employee_presence_policy.delete
        ClearResetJoinTables.call(employee_presence_policy.employee, effective_at, nil, nil)
        find_and_update_employee_balances
      end

      private

      def find_and_update_employee_balances
        update_balances_params = [employee_presence_policy, effective_at.to_date, nil, nil]
        FindAndUpdateEmployeeBalancesForJoinTables.call(*update_balances_params)
      end
    end
  end
end
