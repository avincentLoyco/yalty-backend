module API
  module V1
    class EmployeesController < ApplicationController
      authorize_resource

      def show
        render_resource(resource)
      end

      def index
        render_resource(resources)
      end

      private

      def resource
        @resource ||= resources.find(params[:id])
      end

      def resources
        @resources ||= Account.current.employees
      end

      def resource_representer
        if current_user.owner_or_administrator? ||
            (@resource && current_user.employee.try(:id) == @resource.id)
          ::Api::V1::EmployeeRepresenter
        else
          ::Api::V1::PublicEmployeeRepresenter
        end
      end
    end
  end
end
