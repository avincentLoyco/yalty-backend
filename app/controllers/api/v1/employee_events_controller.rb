module API
  module V1
    class EmployeeEventsController < ApplicationController
      include EmployeeEventSchemas

      DryValidationResult = Struct.new(:attributes, :errors)

      def show
        authorize! :show, resource
        render_resource(resource)
      end

      def index
        authorize! :index, resources.first, params[:employee_id]
        render_resource(resources)
      end

      def create
        verified_dry_params(dry_validation_schema) do |attributes|
          authorize! :create, Employee::Event.new, attributes.except(:employee_attributes)

          verify_employee_attributes_values(attributes[:employee_attributes])
          UpdateEventAttributeValidator.new(attributes[:employee_attributes]).call
          resource = CreateEvent.new(attributes, attributes[:employee_attributes].to_a).call

          render_resource(resource, status: :created)
        end
      end

      def update
        verified_dry_params(dry_validation_schema) do |attributes|
          authorize! :update, resource, attributes.except(:employee_attributes)
          verify_employee_attributes_values(attributes[:employee_attributes])
          UpdateEventAttributeValidator.new(attributes[:employee_attributes]).call
          UpdateEvent.new(attributes, attributes[:employee_attributes].to_a).call
          render_no_content
        end
      end

      def destroy
        authorize! :destroy, resource
        DeleteEvent.new(resource).call
        render_no_content
      end

      private

      def run_quantity_job?
        %w(hired contract_end).include?(resource.event_type)
      end

      def resource
        @resource ||= Account.current.employee_events.find(params[:id])
      end

      def resources
        @resources ||= if params[:employee_id].present?
                         employee.events
                       else
                         Account.current.employee_events.limit(100)
                       end
      end

      def employee
        Account.current.employees.find(params[:employee_id])
      end

      def resource_representer
        ::Api::V1::EmployeeEventRepresenter
      end

      def verify_employee_attributes_values(employee_attributes)
        result_errors =
          employee_attributes.to_a.inject({}) do |errors, attributes|
            result = VerifyEmployeeAttributeValues.new(attributes)
            result.valid? ? errors : errors.merge!(result.errors)
          end

        raise InvalidResourcesError.new(nil, result_errors) unless result_errors.blank?
      end
    end
  end
end
