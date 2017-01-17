module API
  module V1
    class EmployeeAttributesController < API::ApplicationController
      include EmployeeAttributesSchemas

      def show
        verified_dry_params(dry_validation_schema) do |attributes|
          render json: employee_attributes_json(attributes)
        end
      end

      private

      def employee_attributes_json(attributes)
        employee_attributes(attributes).map do |attribute|
          ::Api::V1::EmployeeAttributeRepresenter.new(attribute).complete
        end
      end

      def employee_attributes(attributes)
        employee_id = attributes[:employee_id]
        employee_attributes =
          FullEmployeeAttributesList.new(Account.current.id, employee_id, attributes[:date]).call

        if current_user.account_manager || current_user.employee.try(:id) == employee_id
          employee_attributes
        else
          employee_attributes.try(:visible_for_other_employees)
        end
      end
    end
  end
end
