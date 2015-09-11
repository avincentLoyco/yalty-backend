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
    class EmployeesController < JSONAPI::ResourceController
      skip_before_filter :setup_request, only: [:create]

      def create
        params.deep_transform_keys! {|key| unformat_key(key) }

        # Validate employee data
        employee_data = params.require(:data)

        verify_type(employee_data[:type], EmployeeResource)
        if Employee.where(id: employee_data[:id]).exists?
          fail JSONAPI::Exceptions::EntityAlreadyExists.new(employee_data[:id])
        end

        # Validate and extract event data
        event_data = employee_data.require(:relationships).require(:events).require(:data)

        if !event_data.is_a?(Array) || event_data.size != 1
          fail JSONAP::Exceptions::InvalidLinksObject.new
        end

        verify_type(event_data.first[:type], EmployeeEventResource)

        event_attributes = event_data.first.require(:attributes).permit('effective_at')
        event_attributes[:id] = event_data.first[:id]

        # Create employee
        employee = Account.current.employees.build(id: employee_data[:id])
        event = employee.events.build(event_attributes)

        if employee.save
          render status: :created, nothing: true
        else
          fail JSONAPI::Exceptions::SaveFailed.new
        end
      rescue ActionController::ParameterMissing => e
        render_errors(JSONAPI::Exceptions::ParameterMissing.new(e.param).errors)
      rescue => e
        handle_exceptions(e)
      end

      private

      def verify_type(type, resource_klass)
        if type.nil?
          fail JSONAPI::Exceptions::ParameterMissing.new(:type)
        elsif unformat_key(type).to_sym != resource_klass._type
          fail JSONAPI::Exceptions::InvalidResource.new(type)
        end
      end

      def unformat_key(key)
        unformatted_key = key_formatter.unformat(key)
        unformatted_key.nil? ? nil : unformatted_key.to_sym
      end
    end
  end
end
