module API
  module V1
    class EmployeeEventsController < ApplicationController
      include EmployeeEventSchemas

      DryValidationResult = Struct.new(:attributes, :errors)

      def show
        authorize! :show, Account.current
        render_resource(resource)
      end

      def index
        authorize! :read, Account.current
        render_resource(resources)
      end

      def create
        verified_dry_params(dry_validation_schema) do |attributes|
          authorize! :create, Employee::Event.new, attributes.except(:employee_attributes)

          verify_employee_attributes_values(attributes[:employee_attributes])
          unless current_user.owner_or_administrator?
            UpdateEventAttributeValidator.new(attributes[:employee_attributes]).call
          end
          resource = CreateEvent.new(attributes, attributes[:employee_attributes].to_a).call

          render_resource(resource, status: :created)
        end
      end

      def update
        verified_dry_params(dry_validation_schema) do |attributes|
          authorize! :update, resource, attributes.except(:employee_attributes)
          verify_employee_attributes_values(attributes[:employee_attributes])
          unless current_user.owner_or_administrator?
            UpdateEventAttributeValidator.new(attributes[:employee_attributes]).call
          end
          UpdateEvent.new(attributes, attributes[:employee_attributes].to_a).call
          render_no_content
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
