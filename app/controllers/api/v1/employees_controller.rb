module API
  module V1
    class EmployeesController < ApplicationController
      include EmployeeRules

      def show
        render_resource(resource)
      end

      def index
        render_resource(resources)
      end

      def update
        verified_params(gate_rules) do |attributes|
          related = related_params(attributes).compact
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
        holiday_policy_params(attributes).to_h
          .merge(presence_policy_params(attributes).to_h)
      end

      def presence_policy_params(attributes)
        if attributes[:presence_policy]
          { presence_policy: attributes.delete(:presence_policy).try(:[], :id) }
        end
      end

      def holiday_policy_params(attributes)
        if attributes[:holiday_policy]
          { holiday_policy: attributes.delete(:holiday_policy).try(:[], :id) }
        end
      end

      def assign_related(related_records)
        return true if related_records.empty?
        related_records.each do |key, value|
          assign_member(resource, value, key.to_s)
        end
      end

      def resource
        @resource ||= resources.find(params[:id])
      end

      def resources
        @resources ||= Account.current.employees
      end

      def resource_representer
        ::Api::V1::EmployeeRepresenter
      end
    end
  end
end
