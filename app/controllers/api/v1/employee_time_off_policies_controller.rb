module API
  module V1
    class EmployeeTimeOffPoliciesController < ApplicationController
      before_action :time_off_policy, only: :create
      include EmployeeTimeOffPoliciesRules

      def index
        render_resource(resources)
      end

      def create
        verified_params(gate_rules) do |attributes|
          resource = employee.employee_time_off_policies.create!(attributes.except(:id))
          render_resource(resource, status: 201)
        end
      end

      private

      def resources
        @resources = time_off_policy.employee_time_off_policies
      end

      def employee
        @employee ||= Account.current.employees.find(params[:id])
      end

      def time_off_policy
        Account.current.time_off_policies.find(params[:time_off_policy_id])
      end

      def resource_representer
        ::Api::V1::EmployeeTimeOffPolicyRepresenter
      end
    end
  end
end
