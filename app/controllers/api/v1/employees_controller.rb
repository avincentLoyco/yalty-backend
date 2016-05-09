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
          transactions do
            assign_related(related)
          end
          render_no_content
        end
      end

      private

      def related_params(attributes)
        related = {}

        if attributes.key?(:holiday_policy)
          holiday_policy = { holiday_policy: attributes.delete(:holiday_policy) }
        end

        related.merge(holiday_policy.to_h)
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
        if current_user.account_manager ||
            (@resource && current_user.employee.try(:id) == @resource.id)
          ::Api::V1::EmployeeRepresenter
        else
          ::Api::V1::PublicEmployeeRepresenter
        end
      end
    end
  end
end
