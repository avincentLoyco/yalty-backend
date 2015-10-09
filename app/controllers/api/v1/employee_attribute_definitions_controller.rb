module API
  module V1
    class EmployeeAttributeDefinitionsController < API::ApplicationController
      include AttributeDefinitionRules

      def index
        response = attributes.map do |attr|
          AttributeDefinitionRepresenter
            .new(attr)
            .complete
        end

        render json: response
      end

      def show
        render_json(attribute)
      end

      def create
        verified_params(gate_rules) do |attr|
          new_attribute = Account.current.employee_attribute_definitions.new(attr)
          if new_attribute.save
            render_json(new_attribute)
          else
            render_error_json(new_attribute)
          end
        end
      end

      def update
        verified_params(gate_rules) do |attr|
          if attribute.update(attr)
            render_no_content
          else
            render_error_json(attribute)
          end
        end
      end

      def destroy
        if attribute.employee_attributes.blank? && !attribute.system?
          attribute.destroy!
          head 204
        else
          locked_error
        end
      end

      private

      def attributes
        @attributes ||= Account.current.employee_attribute_definitions
      end

      def attribute
        @attribute ||= attributes.find(params[:id])
      end

      def render_json(attr_definition)
        render json: AttributeDefinitionRepresenter.new(attr_definition).complete
      end

    end
  end
end
