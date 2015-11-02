module API
  module V1
    class EmployeesController < ApplicationController
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
        ::Api::V1::EmployeeRepresenter
      end
    end
  end
end
