module API
  module V1
    class EmployeeAttributeDefinitionsController < API::ApplicationController

      def index
        response = attributes.map do |attr|
          AttributeDefinitionRepresenter
            .new(attr)
            .complete
        end

        render json: response
      end

      def show
        render json: AttributeDefinitionRepresenter
          .new(attribute)
          .complete
      end

      def create
        verified_params(gate_rules) do |attr|
          new_attribute = Account.current.employee_attribute_definitions.new(attr)
          if new_attribute.save
            render json: AttributeDefinitionRepresenter
              .new(new_attribute)
              .complete
          else
            render json: ErrorsRepresenter
              .new(new_attribute.errors.messages, 'employee_attribute_definition')
              .resource,
              status: 422
          end
        end
      end

      def update
        verified_params(gate_rules) do |attr|
          if attribute.update(attr)
            render status: :no_content, nothing: true
          else
            render json: ErrorsRepresenter
              .new(attribute.errors.messages, 'employee_attribute_definition')
              .resource,
              status: 422
          end
        end
      end

      def destroy
        #TODO no system
        if attribute.employee_attributes.blank?
          attribute.destroy!
          head 204
        else
          render json: { status: "error", message: "Method Not Allowed" },
            status: 405
        end
      end

      private

      def attributes
        @attributes ||= Account.current.employee_attribute_definitions
      end

      def attribute
        @attribute ||= attributes.find(params[:id])
      end

      def gate_rules
        result = put_rules     if request.put?
        result = patch_rules   if request.patch?
        result = post_rules    if request.post?
        result = get_rules     if request.get?
        result = delete_rules  if request.delete?
        result
      end

      def patch_rules
        Gate.rules do
          required :id
          required :name
          optional :label
          required :attribute_type
          required :system
        end
      end

      def post_rules
        Gate.rules do
          required :name
          optional :label
          required :attribute_type
          required :system
        end
      end

      def put_rules
        Gate.rules do
          required :id
          required :name
          optional :label
          required :attribute_type
          required :system
        end
      end

    end
  end
end
