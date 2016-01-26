module API
  module V1
    class EmployeesController < ApplicationController
      authorize_resource
      include EmployeeRules

      def show
        render_resource(resource)
      end

      def index
        render_resource(resources)
      end

      def update
        verified_params(gate_rules) do |attributes|
          related = related_params(attributes)
          result = transactions do
            assign_related(related)
          end
          if result
            render_no_content
          else
            resource_invalid_error(resource)
          end
        end
      end

      private

      def related_params(attributes)
        related = {}

        if attributes.key?(:holiday_policy)
          holiday_policy = { holiday_policy: attributes.delete(:holiday_policy) }
        end

        if attributes.key?(:presence_policy)
          presence_policy = { presence_policy: attributes.delete(:presence_policy) }
        end

        related.merge(holiday_policy.to_h)
          .merge(presence_policy.to_h)
      end

      def assign_related(related_records)
        return true if related_records.empty?
        related_records.each do |key, value|
          assign_member(resource, value.try(:[], :id), key.to_s)
        end
      end

      def resource
        @resource ||= resources.find(params[:id])
      end

      def resources
        @resources ||= Account.current.employees
      end

      def resource_representer
        if current_user.account_manager
          ::Api::V1::EmployeeRepresenter
        else
          ::Api::V1::PublicEmployeeRepresenter
        end
      end
    end
  end
end
