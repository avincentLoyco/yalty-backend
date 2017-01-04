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
          verify_employee_attributes_values(attributes[:employee_attributes])
          resource = CreateEvent.new(attributes, attributes[:employee_attributes].to_a).call
          authorize! :create, resource
          render_resource(resource, status: :created)
        end
      end

      def update
        verified_dry_params(dry_validation_schema) do |attributes|
          authorize! :update, resource

          verify_employee_attributes_values(attributes[:employee_attributes])
          unless current_user.account_manager
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
        errors = {}
        employee_attributes.to_a.map do |attributes|
          result = VerifyEmployeeAttributeValues.new(attributes)
          result.valid?
          errors.merge!(result.errors)
        end
        raise InvalidResourcesError.new(nil, errors) unless errors.blank?
      end
    end
  end
end
