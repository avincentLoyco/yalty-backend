module API
  module V1
    class EmployeePresencePoliciesController < ApplicationController
      include EmployeePresencePoliciesSchemas

      def index
        authorize! :index, presence_policy
        render_resource(resources)
      end

      def create
        verified_dry_params(dry_validation_schema) do |attributes|
          authorize! :create, presence_policy
          resource = create_or_update_join_table(EmployeePresencePolicy, PresencePolicy, attributes)
          render_resource(resource, status: 201)
        end
      end

      def update
        verified_dry_params(dry_validation_schema) do |attributes|
          authorize! :update, resource
          actual_resource =
            create_or_update_join_table(
              EmployeePresencePolicy, PresencePolicy, attributes, resource
            )
          render_resource(actual_resource)
        end
      end

      private

      def resource
        @resource ||= Account.current.employee_presence_policies.find(params[:id])
      end

      def employee
        @employee ||= Account.current.employees.find(params[:id])
      end

      def presence_policy
        @presence_policy ||= Account.current.presence_policies.find(params[:presence_policy_id])
      end

      def resources
        resources_with_effective_till(EmployeePresencePolicy, nil, presence_policy.id)
      end

      def resource_representer
        ::Api::V1::EmployeePresencePolicyRepresenter
      end
    end
  end
end
