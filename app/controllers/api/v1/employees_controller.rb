module API
  module V1
    class EmployeesController < ApplicationController
      authorize_resource

      def show
        render_resource(resource)
      end

      def index
        render_resources
      end

      private

      def resource_representer
        if current_user.owner_or_administrator? ||
            (@resource && current_user.employee.try(:id) == @resource.id)
          ::Api::V1::EmployeeRepresenter
        else
          ::Api::V1::PublicEmployeeRepresenter
        end
      end

      def render_resources
        response = resources.map do |employee|
          if current_user.owner_or_administrator? || current_user.employee.try(:id) == employee.id
            ::Api::V1::EmployeeRepresenter.new(employee).complete
          else
            ::Api::V1::PublicEmployeeRepresenter.new(employee).complete
          end
        end
        render json: response
      end

      def resource
        @resource ||= resources.find(params[:id])
      end

      def resources
        @resources ||= Account.current.employees.send(resources_scope)
      end

      def resources_scope
        case params[:status]
        when 'active' then 'active_at_date'
        when 'inactive' then 'inactive_at_date'
        else 'all'
        end
      end
    end
  end
end
