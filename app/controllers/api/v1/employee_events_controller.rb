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

      # version with employee_management_usage
      # def create
      #   verified_params(gate_rules) do |attributes|
      #     load_or_build_employee(attributes[:employee])
      #     build_employee_event(attributes)
      #     build_employee_attributes(attributes[:employee][:employee_attributes])
      #     event = save_entities
      #     if event.persisted?
      #       render_resource(event, status: :created)
      #     else
      #       resource_invalid_error(resource)
      #     end
      #   end
      # end

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
