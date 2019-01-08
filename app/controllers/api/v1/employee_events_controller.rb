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
          authorize! :create, event_for_auth(attributes)
          verify_employee_attributes_values(attributes[:employee_attributes])
          UpdateEventAttributeValidator.new(attributes[:employee_attributes]).call
          new_resource = event_service_class.new.call(attributes)

          render_resource(new_resource, status: :created)
        end
      end

      def update
        verified_dry_params(dry_validation_schema) do |attributes|
          authorize! :update, resource, attributes.except(:employee_attributes)
          verify_employee_attributes_values(attributes[:employee_attributes])
          UpdateEventAttributeValidator.new(attributes[:employee_attributes]).call
          event_service_class.new.call(resource, attributes)

          render_no_content
        end
      end

      def destroy
        authorize! :destroy, resource
        event_service_class.new.call(resource)

        render_no_content
      end

      private

      def resource
        @resource ||= Account.current.employee_events.find_by!(id: params[:id])
      end

      def resources
        @resources ||= if params[:employee_id].present?
                         employee.events.order(effective_at: :asc, event_type: :desc)
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

      def event_service_type
        case event_type
        when "hired", "work_contract"
          "WorkContract"
        when "contract_end"
          "ContractEnd"
        when "adjustment_of_balances"
          "Adjustment"
        else
          "Default"
        end
      end

      def event_type
        params["event_type"] || resource.event_type
      end

      def event_service_class(action: action_name)
        Events.const_get(event_service_type).const_get(action.classify)
      end

      def event_for_auth(attributes)
        Employee::Event.new(
          employee_id: attributes.dig(:employee, :id),
          event_type: attributes[:event_type]
        )
      end
    end
  end
end
