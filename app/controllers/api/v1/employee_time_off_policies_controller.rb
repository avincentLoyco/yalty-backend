module API
  module V1
    class EmployeeTimeOffPoliciesController < ApplicationController
      include EmployeeTimeOffPoliciesRules

      def index
        authorize! :index, time_off_policy
        render_resource(resources)
      end

      def create
        verified_params(gate_rules) do |attributes|
          authorize! :create, time_off_policy
          resource = employee.employee_time_off_policies.new(attributes.except(:id))

          transactions do
            resource.save!
            ManageEmployeeBalanceAdditions.new(resource).call
          end

          resource = resources_with_effective_till(EmployeeTimeOffPolicy, resource.id).first
          render_resource(resource, status: 201)
        end
      end

      private

      def resources
        resources_with_effective_till(EmployeeTimeOffPolicy, nil, time_off_policy.id)
      end

      def employee
        @employee ||= Account.current.employees.find(params[:id])
      end

      def time_off_policy
        @time_off_policy = Account.current.time_off_policies.find(params[:time_off_policy_id])
      end

      def resource_representer
        ::Api::V1::EmployeeTimeOffPolicyRepresenter
      end
    end
  end
end
