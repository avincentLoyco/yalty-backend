module API
  module V1
    class EmployeeEventsController < ApplicationController
      include EmployeeEventRules

      def show
        render_resource(resource)
      end

      def index
        render_resource(resources)
      end

      def create
        verified_params(gate_rules) do |attributes|
          resource = CreateEvent.new(attributes).call
          if resource.persisted?
            render_resource(resource, status: :created)
          else
            resource_invalid_error(resource)
          end
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          resource = UpdateEvent.new(attributes, request.method).call
          if !resource.errors.any?
            render_no_content
          else
            resource_invalid_error(resource)
          end
        end
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
