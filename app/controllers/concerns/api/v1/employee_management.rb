require 'active_support/concern'

module API
  module V1
    module EmployeeManagement
      extend ActiveSupport::Concern
      include API::V1::ParamsManagement
      include API::V1::ExceptionsHandler

      private

      def build_employee(data)
        verify_type(data[:type], EmployeeResource)
        verify_entity_uniqueness(data[:id], Employee)

        @employee = Account.current.employees.build(id: data[:id])
      end

      def load_employee(data)
        verify_type(data[:type], EmployeeResource)

        @employee = Account.current.employees
          .where(id: data.require(:id))
          .first!
      end

      def build_employee_event(data)
        if data.is_a?(Array) && data.size != 1
          fail JSONAP::Exceptions::InvalidLinksObject
        end

        data = data.first if data.is_a?(Array)

        verify_type(data[:type], EmployeeEventResource)
        verify_entity_uniqueness(data[:id], Employee::Event)

        event_attributes = data
          .require(:attributes)
          .permit(:effective_at, :comment, :event_type)
        event_attributes[:id] = data[:id]

        @event = @employee.events.build(event_attributes)
      end

      def build_employee_attributes(data)
        if !data.is_a?(Array) || data.size < 1
          fail JSONAP::Exceptions::InvalidLinksObject
        end

        data.each do |attr|
          build_employee_attribute(attr)
        end
      end

      def build_employee_attribute(data)
        verify_type(data[:type], EmployeeAttributeResource)
        verify_entity_uniqueness(data[:id], Employee::AttributeVersion)

        attribute_definition = load_attribute_definition(data)

        attribute = @event.employee_attribute_versions.build(
          id: data[:id],
          employee: @employee,
          attribute_definition: attribute_definition
        )
        attribute.value = data.require(:attributes).require(:value)
      end

      def load_attribute_definition(data)
        attribute_definition_id = data
          .require(:relationships)
          .require(:attribute_definition)
          .require(:data).require(:id)

        Account.current.employee_attribute_definitions
          .where(id: attribute_definition_id)
          .first
      end

      def save_employee
        @employee.save!
      rescue
        raise JSONAPI::Exceptions::SaveFailed
      end

      def save_event
        @event.save!
      rescue
        raise JSONAPI::Exceptions::SaveFailed
      end
    end
  end
end
