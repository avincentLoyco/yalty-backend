module API
  module V1
    class EmployeeAttributeDefinitionsController < API::ApplicationController
      authorize_resource class: 'Employee::AttributeDefinition', except: :create
      include EmployeeAttributeDefinitionSchemas

      def index
        render_resource(resources)
      end

      def show
        render_resource(resource)
      end

      def create
        verified_dry_params(dry_validation_schema) do |attributes|
          @resource = Account.current.employee_attribute_definitions.new(attributes)
          authorize! :create, resource

          resource.save!
          render_resource(resource)
        end
      end

      def update
        verified_dry_params(dry_validation_schema) do |attributes|
          resource.update!(attributes)
          render_no_content
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
        ::Api::V1::EmployeeAttributeDefinitionRepresenter
      end
    end
  end
end
