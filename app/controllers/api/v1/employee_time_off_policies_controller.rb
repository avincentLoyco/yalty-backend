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
            @resource, @status = create_or_update_join_table(TimeOffPolicy, join_table_params)
            if @status.eql?(201)
              @balance = create_new_employee_balance(@resource)
              ManageEmployeeBalanceAdditions.new(@resource).call
            end
          end

          render_resource(@resource, status: @status)
        end
      end

      def update
        verified_dry_params(dry_validation_schema) do |attributes|
          authorize! :update, resource
          transactions do
            @updated_resource, @status =
              create_or_update_join_table(TimeOffPolicy, attributes, resource)
            ManageEmployeeBalanceAdditions.new(@updated_resource).call
          end

          render_resource(@updated_resource, status: @status)
        end
      end

      def destroy
        authorize! :destroy, resource
        transactions do
          resource.policy_assignation_balance.try(:destroy!)
          destroy_join_tables_with_duplicated_resources
          verify_if_there_are_no_balances!
          resource.destroy!
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
