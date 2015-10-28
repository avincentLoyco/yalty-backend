module API
  module V1
    class EmployeeEventsController < ApplicationController
      include EmployeeEventRules
      GateResult = Struct.new(:attributes, :errors)

      def show
        render_resource(resource)
      end

      def index
        render_resource(resources)
      end

      def create
        verified_params(gate_rules) do |attributes, employee_attributes|
          resource = CreateEvent.new(attributes, employee_attributes).call

          if resource.persisted?
            render_resource(resource, status: :created)
          else
            resource_invalid_error(resource)
          end
        end
      end

      def update
        verified_params(gate_rules) do |attributes, employee_attributes|
          resource = UpdateEvent.new(attributes, employee_attributes).call
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
        ::Api::V1::EmployeeEventRepresenter
      end

      def verified_params(rules)
        event_result = rules.verify(params)
        attributes_results, attributes_errors = verify_employee_attributes

        if event_result.valid? && attributes_errors.blank?
          yield(event_result.attributes, attributes_results)
        else
          result_errors = merge_errors(event_result, attributes_errors)
          resource_invalid_error(result_errors)
        end
      end

      def merge_errors(base, results_errors)
        new_result = GateResult.new

        results_errors.each do |result|
          new_result.attributes = base.attributes.merge(result.attributes)
          new_result.errors = base.errors.merge(result.errors)
        end

        new_result
      end

      def verify_employee_attributes
        results = []
        errors = []
        nested_gate_rules = EmployeeAttributeVersionRules.new.gate_rules(request)

        params[:employee][:employee_attributes].each do |employee_attribute|
          result = nested_gate_rules.verify(employee_attribute)
          if result.valid?
            results << result.attributes
          else
            errors << result
          end
        end
        [results, errors]
      end
    end
  end
end
