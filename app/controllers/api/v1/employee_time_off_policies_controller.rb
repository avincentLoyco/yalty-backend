module API
  module V1
    class EmployeeTimeOffPoliciesController < ApplicationController
      include EmployeeTimeOffPoliciesSchemas

      def index
        authorize! :index, time_off_policy
        render_resource(resources)
      end

      def create
        verified_dry_params(dry_validation_schema) do |attributes|
          authorize! :create, time_off_policy
          employee_balance_amount = attributes.delete(:employee_balance_amount)

          transactions do
            @resource = create_join_table(EmployeeTimeOffPolicy, TimeOffPolicy, attributes)
            create_new_employee_balance(@resource) if employee_balance_amount
            ManageEmployeeBalanceAdditions.new(@resource).call
          end

          render_resource(@resource, status: 201)
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
        @time_off_policy ||= Account.current.time_off_policies.find(params[:time_off_policy_id])
      end

      def create_new_employee_balance(resource)
        CreateEmployeeBalance.new(
          resource.time_off_category_id,
          resource.employee_id,
          Account.current.id,
          options_for(resource)
        ).call
      end

      def options_for(resource)
        {
          employee_time_off_policy_id: resource.id,
          amount: params[:employee_balance_amount],
          effective_at: resource.effective_at
        }
      end

      def resource_representer
        ::Api::V1::EmployeeTimeOffPolicyRepresenter
      end
    end
  end
end
