module API
  module V1
    class EmployeePresencePoliciesController < ApplicationController
      include EmployeePresencePoliciesRules

      def create
        verified_params(gate_rules) do |attributes|
          authorize! :create, presence_policy
          resource = employee.employee_presence_policies.new(attributes.except(:id))
          transactions do
            resource.save!
          end
          resource = resource_with_effective_till(resource.id)
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

      def resource_with_effective_till(resource_id)
        epp_hash =
          JoinTableWithEffectiveTill
          .new(EmployeePresencePolicy,
            current_user.account_id,
            nil,
            nil,
            resource_id)
          .call
          .first
        EmployeePresencePolicy.new(epp_hash)
      end

      def resources
        @resources ||=
          JoinTableWithEffectiveTill
          .new(EmployeePresencePolicy, current_user.account_id, presence_policy.id)
          .call
        @resources = resources_with_effective_till(@resources)
      end

      def resources_with_effective_till(epps_array)
        epps_array.map do |epp_hash|
          EmployeePresencePolicy.new(epp_hash)
        end
      end

      def presence_policy
        Account.current.presence_policies.find(params[:presence_policy_id])
      end

      def resource_representer
        ::Api::V1::EmployeePresencePolicyRepresenter
      end
    end
  end
end
