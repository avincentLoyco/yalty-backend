module API
  module V1
    class EmployeePresencePoliciesController < ApplicationController
      include EmployeePresencePoliciesSchemas
      include EmployeeBalancesPresenceVerification

      def index
        authorize! :index, presence_policy
        render_resource(resources_with_filters(EmployeePresencePolicy, presence_policy.id))
      end

      def create
        verified_dry_params(dry_validation_schema) do |attributes|
          authorize! :create, presence_policy
          attributes[:employee_id] = attributes.delete(:id)
          response = create_or_update_join_table(PresencePolicy, attributes)
          find_and_update_balances(response[:result], attributes)
          render_join_table(response[:result], response[:status])
        end
      end

      def update
        verified_dry_params(dry_validation_schema) do |attributes|
          authorize! :update, resource
          previous_date = resource.effective_at
          find_attributes =
            attributes.merge(previous_order_of_start_day: resource.order_of_start_day)
          response = create_or_update_join_table(PresencePolicy, attributes, resource)
          find_and_update_balances(response[:result], find_attributes, previous_date)
          render_join_table(response[:result], response[:status])
        end
      end

      def destroy
        authorize! :destroy, resource
        transactions do
          resource.destroy!
          clear_respective_reset_join_tables(resource.employee, resource.effective_at)
          destroy_join_tables_with_duplicated_resources
          find_and_update_balances(resource)
        end
        render_no_content
      end

      private

      def resource
        @resource ||= Account.current.employee_presence_policies.not_reset.find(params[:id])
      end

      def presence_policy
        @presence_policy ||= Account.current.presence_policies.find(params[:presence_policy_id])
      end

      def resource_representer
        ::Api::V1::EmployeePresencePolicyRepresenter
      end
    end
  end
end
