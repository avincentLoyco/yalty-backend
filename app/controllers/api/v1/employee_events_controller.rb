module API
  module V1
    class EmployeeEventsController < ApplicationController
      include EmployeeEventRules
      include EmployeeManagement

      def show
        render_resource(resource)
      end

      def index
        render_resource(resources)
      end

      def create
        verified_params(gate_rules) do |attributes|
          event = CreateEvent.new(attributes).call
          if event.persisted?
            render_resource(event, status: :created)
          else
            resource_invalid_error(resource)
          end
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          event = UpdateEvent.new(attributes, request.method).call
          if event
            render_resource(event, status: :created)
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
