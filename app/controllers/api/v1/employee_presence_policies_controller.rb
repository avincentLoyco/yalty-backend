module API
  module V1
    class EmployeePresencePoliciesController < ApplicationController
      include EmployeePresencePoliciesRules

      def create
        verified_params(gate_rules) do |attributes|
          authorize! :create, presence_policy
          resource = create_join_table(EmployeePresencePolicy, PresencePolicy, attributes)
          render_resource(resource, status: 201)
        end
      end

      def index
        authorize! :index, presence_policy
        render_resource(resources)
      end

      private

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
