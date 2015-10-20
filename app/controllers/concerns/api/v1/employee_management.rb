require 'active_support/concern'

module API
  module V1
    module EmployeeManagement
      extend ActiveSupport::Concern
      include API::V1::ParamsManagement

      private

      def load_or_build_employee(data)
        if data.key?(:id)
          @employee = Account.current.employees.find(data[:id])
        else
          @employee = Account.current.employees.new
        end
      end

      def build_employee_event(data)
        @event = @employee.events.new(data.except(:employee))
      end

      def build_employee_attributes(data)
        data.each do |attr|
          build_employee_attribute(attr)
        end
      end

      def build_employee_attribute(data)
        # verify_entity_uniqueness(data[:id], Employee::AttributeVersion)
        attribute_definition = load_attribute_definition(data)
        attribute = @event.employee_attribute_versions.build(
          # id: data[:id],
          employee: @employee,
          attribute_definition: attribute_definition
        )
        attribute.value = data.require(:value)
      end

      def load_attribute_definition(data)
        Account.current.employee_attribute_definitions.find_by!(name: data[:attribute_name])
      end

      def save_entities
        ActiveRecord::Base.transaction do
          begin
            @employee.save!
            @event.employee_attribute_versions.each do |version|
              version.employee = @employee
              version.save!
            end
          rescue
            raise ActiveRecord::Rollback
          end
        end
        @event
      end
    end
  end
end
