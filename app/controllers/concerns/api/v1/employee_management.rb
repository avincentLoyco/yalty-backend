require 'active_support/concern'
require 'jsonapi/exceptions'

module JSONAPI
  module Exceptions
    class EntityAlreadyExists < Error
      def initialize(id)
        @id = id
      end

      def errors
        [
          JSONAPI::Error.new(
            code: JSONAPI::SAVE_FAILED,
            status: :conflict,
            title: 'Entity already exists',
            detail: "Entity with id '#{@id} already exists'"
          )
        ]
      end
    end
  end
end

module API
  module V1
    module EmployeeManagement
      extend ActiveSupport::Concern

      private

      def setup_employee_management
        params.deep_transform_keys! {|key| unformat_key(key) }
      end

      def build_employee(data)
        verify_type(data[:type], EmployeeResource)
        verify_entity_uniqueness(data[:id], Employee)

        @employee = Account.current.employees.build(id: data[:id])
      end

      def build_employee_event(data)
        if !data.is_a?(Array) || data.size != 1
          fail JSONAP::Exceptions::InvalidLinksObject.new
        end

        data = data.first

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
          fail JSONAP::Exceptions::InvalidLinksObject.new
        end

        data.each do |attr|
          verify_type(attr[:type], EmployeeAttributeResource)
          verify_entity_uniqueness(attr[:id], Employee::AttributeVersion)

          attribute_definition = Account.current.employee_attribute_definitions
          .where(
            id: attr.require(:relationships).require(:attribute_definition).require(:data).require(:id)
          ).first

          attribute = @employee.employee_attribute_versions.build(
            id: attr[:id],
            event: @event,
            attribute_definition: attribute_definition
          )
          attribute.value = attr.require(:attributes).require(:value)
        end
      end

      def save_employee
        @employee.save!
      rescue
        fail JSONAPI::Exceptions::SaveFailed.new
      end

      def verify_type(type, resource_klass)
        if type.nil?
          fail JSONAPI::Exceptions::ParameterMissing.new(:type)
        elsif unformat_key(type).to_sym != resource_klass._type
          fail JSONAPI::Exceptions::InvalidResource.new(type)
        end
      end

      def verify_entity_uniqueness(id, entity_klass)
        if id.present? && entity_klass.where(id: id).exists?
          fail JSONAPI::Exceptions::EntityAlreadyExists.new(id)
        end
      end

      def unformat_key(key)
        unformatted_key = key_formatter.unformat(key)
        unformatted_key.nil? ? nil : unformatted_key.to_sym
      end

      def handle_exceptions(e)
        case e
        when ActionController::ParameterMissing
          render_errors(JSONAPI::Exceptions::ParameterMissing.new(e.param).errors)
        else
          super(e)
        end
      end
    end
  end
end
