module API
  module V1
    class EmployeeEventsController < ApplicationController
      def show
        render_resource(resource)
      end

      def index
        render_resource(resources)
      end

      private

      def resource
        @resource ||= Account.current.employee_events.find(params[:id])
      end

      def resources
        @resources ||= employee.events
      end

      def employee
        Account.current.employees.find(params[:employee_id])
      end

      def resource_representer
        ::V1::EmployeeEventRepresenter
      end
    end
  end
end
