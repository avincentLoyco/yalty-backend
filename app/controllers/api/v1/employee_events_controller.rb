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

          verify_rehired_event(attributes.except(:employee_attributes))
          verify_employee_attributes_values(attributes[:employee_attributes])
          UpdateEventAttributeValidator.new(attributes[:employee_attributes]).call
          resource = CreateEvent.new(attributes, attributes[:employee_attributes].to_a).call

          render_resource(resource, status: :created)
        end
      end

      def update
        verified_dry_params(dry_validation_schema) do |attributes|
          authorize! :update, resource, attributes.except(:employee_attributes)
          verify_rehired_event(attributes.except(:employee_attributes))
          verify_employee_attributes_values(attributes[:employee_attributes])
          UpdateEventAttributeValidator.new(attributes[:employee_attributes]).call
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

      def verify_rehired_event(event_attributes)
        hired_or_contract_end = %w(hired contract_end).include?(event_attributes[:event_type])
        return unless event_attributes[:employee][:id].present? && hired_or_contract_end

        cannot_create_event =
          InvalidResourcesError.new(nil, message: "Event can't be at this date")

        raise cannot_create_event if events_too_close(event_attributes)
      end

      def events_too_close(event_attributes)
        em = Account.current.employees.find(event_attributes[:employee][:id])
        event_type = event_attributes[:event_type]
        effective_at = event_attributes[:effective_at]
        date = event_type.eql?('hired') ? effective_at - 1.day : effective_at + 1.day
        type_to_find = event_type.eql?('hired') ? 'contract_end' : 'hired'

        em.events.where(event_type: type_to_find).where('effective_at = ?', date).exists?
      end
    end
  end
end
