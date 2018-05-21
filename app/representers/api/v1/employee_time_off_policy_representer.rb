module Api
  module V1
    class EmployeeTimeOffPolicyRepresenter < BaseRepresenter
      def complete
        {
          assignation_id: resource.id,
          assignation_type: resource_type,
          effective_at: resource.effective_at,
          effective_till: resource.effective_till,
          employee_balance: employee_balance_json,
        }
          .merge(employee_json)
      end

      def employee_json
        EmployeeRepresenter.new(resource.employee).basic
      end

      def employee_balance_json
        return unless resource.policy_assignation_balance.present?
        EmployeeBalanceRepresenter.new(resource.policy_assignation_balance).complete
      end
    end
  end
end
