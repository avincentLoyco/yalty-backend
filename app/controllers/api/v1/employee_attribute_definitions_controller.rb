module API
  module V1
    class EmployeeAttributeDefinitionsController < API::ApplicationController
      include EmployeeAttributeDefinitionRules

      def index
        render_resource(resources)
      end

      def show
        render_resource(resource)
      end

      def create
        verified_params(gate_rules) do |attributes|
          @resource = Account.current.employee_attribute_definitions.new(attributes)

          if resource.save
            render_resource(resource)
          else
            resource_invalid_error(resource)
          end
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          if resource.update(attributes)
            render_no_content
          else
            resource_invalid_error(resource)
          end
        end
      end

      def destroy
        if resource.employee_attributes.blank? && !resource.system?
          resource.destroy!
          render_no_content
        else
          locked_error
        end
      end

      private

      def resources
        @resources ||= Account.current.employee_attribute_definitions
      end

      def resource
        @resource ||= resources.find(params[:id])
      end

      def resource_representer
        EmployeeAttributeDefinitionRepresenter
      end
    end
  end
end
