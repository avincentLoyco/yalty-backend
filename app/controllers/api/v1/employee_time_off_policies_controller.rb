module API
  module V1
    class EmployeeTimeOffPoliciesController < ApplicationController
      include EmployeeTimeOffPoliciesSchemas
      include EmployeeBalancesPresenceVerification

      def index
        authorize! :index, time_off_policy
        render_resource(resources)
      end

      def create
        verified_dry_params(dry_validation_schema) do |attributes|
          authorize! :create, time_off_policy
          join_table_params = attributes.except(:employee_balance_amount)
          transactions do
            @response = create_or_update_join_table(TimeOffPolicy, join_table_params)
            resource = @response[:result]
            RecreateBalances::AfterEmployeeTimeOffPolicyCreate.new(
              new_effective_at: attributes[:effective_at],
              time_off_category_id: resource.time_off_category_id,
              employee_id: resource.employee_id,
              manual_amount: params[:employee_balance_amount]
            ).call
          end

          render_join_table(@response[:result], @response[:status])
        end
      end

      def update
        verified_dry_params(dry_validation_schema) do |attributes|
          authorize! :update, resource
          transactions do
            old_effective_at = resource.effective_at
            @response = create_or_update_join_table(TimeOffPolicy, attributes, resource)
            RecreateBalances::AfterEmployeeTimeOffPolicyUpdate.new(
              new_effective_at: attributes[:effective_at],
              old_effective_at: old_effective_at,
              time_off_category_id: resource.time_off_category_id,
              employee_id: resource.employee_id,
              manual_amount: params[:employee_balance_amount]
            ).call
          end

          render_join_table(@response[:result], @response[:status])
        end
      end

      def destroy
        authorize! :destroy, resource
        transactions do
          destroy_join_tables_with_duplicated_resources
          resource.destroy!
          RecreateBalances::AfterEmployeeTimeOffPolicyDestroy.new(
            destroyed_effective_at: resource.effective_at,
            time_off_category_id: resource.time_off_category_id,
            employee_id: resource.employee_id
          ).call
        end
        render_no_content
      end

      private

      def resource
        @resource ||= Account.current.employee_time_off_policies.find(params[:id])
      end

      def resources
        resources_with_effective_till(EmployeeTimeOffPolicy, nil, time_off_policy.id)
      end

      def time_off_policy
        @time_off_policy ||= Account.current.time_off_policies.find(params[:time_off_policy_id])
      end

      def resource_representer
        ::Api::V1::EmployeeTimeOffPolicyRepresenter
      end
    end
  end
end
