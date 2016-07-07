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
        verified_dry_params(dry_validation_schema) do |event_attributes, employee_attributes|
          resource = CreateEvent.new(event_attributes, employee_attributes).call
          authorize! :create, resource
          render_resource(resource, status: :created)
        end
      end

      def update
        verified_dry_params(dry_validation_schema) do |event_attributes, employee_attributes|
          authorize! :update, resource
          UpdateEventAttributeValidator.new(employee_attributes).call unless
            current_user.account_manager
          UpdateEvent.new(event_attributes, employee_attributes).call

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

      def verified_dry_params(schema)
        event_result = schema.call(params)
        attributes_results, attributes_errors = verify_employee_attributes
        if event_result.messages.empty? && attributes_errors.blank?
          yield(event_result.output, attributes_results)
        else
          result_errors = merge_errors(event_result, attributes_errors)
          resource_invalid_error(result_errors)
        end
      end

      def merge_errors(base, results_errors)
        new_result = DryValidationResult.new(base.output, base.errors)
        results_errors.each do |result|
          new_result.attributes = new_result.attributes.merge(result.try(:attributes) || {})
          new_result.errors = new_result.errors.push(result.errors)
        end
        new_result
      end

      def verify_employee_attributes
        # TODO: temporary solution we are waiting for issue:
        # https://github.com/monterail/gate/issues/1
        return [[], []] unless params[:employee_attributes]

        results = []
        errors = []

        nested_gate_rules = EmployeeAttributeVersionSchemas.new.dry_validation_schema(request)
        params[:employee_attributes].each do |employee_attribute|
          attribute_result = nested_gate_rules.call(employee_attribute)
          value_result = VerifyEmployeeAttributeValues.new(employee_attribute)
          if attribute_result.messages.empty? && value_result.valid?
            results << attribute_result.output
          else
            errors << attribute_result
            errors << value_result
          end
        end
        [results, errors]
      end
    end
  end
end
