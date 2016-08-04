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
          join_table_params = attributes.except(:employee_balance_amount)

          transactions do
            @resource =
              create_or_update_join_table(EmployeeTimeOffPolicy, TimeOffPolicy, join_table_params)
            @balance = create_new_employee_balance(@resource) if resource_newly_created?(@resource)
            ManageEmployeeBalanceAdditions.new(@resource).call if resource_newly_created?(@resource)
          end

          render_resource(@resource, status: @balance ? 201 : 200)
        end
      end

      private

      def resource_newly_created?(resource)
        @resource_newly_created ||=
          resource.effective_at == params[:effective_at].to_date &&
          resource.employee_balances.blank?
      end

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
          manual_amount: params[:employee_balance_amount] || 0,
          effective_at: resource.effective_at,
          validity_date: RelatedPolicyPeriod.new(resource).validity_date_for(resource.effective_at)
        }
      end

      def resource_representer
        ::Api::V1::EmployeeTimeOffPolicyRepresenter
      end
    end
  end
end
