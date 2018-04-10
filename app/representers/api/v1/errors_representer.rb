module Api::V1
  class ErrorsRepresenter < BaseRepresenter
    attr_reader :resource, :messages

    def initialize(resource, messages = nil)
      super(resource)
      @messages = messages
    end

    def complete
      response = {}

      response[:errors] = if resource.is_a?(API::V1::Exceptions::CustomError)
                            get_errors_from_exception(resource)
                          else
                            get_errors_from_resource(resource)
                          end

      response
    end

    def get_errors_from_exception(exception)
      [{
        type: exception.type,
        messages: exception.messages,
        field: exception.field,
        codes: exception.codes
      }]
    end

    def get_errors_from_resource(resource)
      if @messages.blank?
        @messages = if resource.is_a?(ActiveRecord::Base)
                      resource.errors.messages
                    elsif resource.is_a?(Struct)
                      resource.errors
                    else
                      []
                    end
      end

      errors = @messages.map do |field, messages|
        {
          field: field.to_s,
          messages: messages,
          status: "invalid",
          type: resource_type,
          codes: generate_codes(field, messages).flatten,
          employee_id: join_table_employee_id
        }
      end
      errors
    end

    def join_table_employee_id
      return if !resource.is_a?(ActiveRecord::Base) ||
          (Employee::RESOURCE_JOIN_TABLES.exclude?(resource.model_name.route_key) &&
          !resource.model_name.name.eql?("Employee::Event"))
      resource&.employee&.id
    end

    def generate_codes(field, messages)
      return [] if messages.blank?
      messages.map do |message|
        next unless message.present?
        if message.is_a?(Array)
          nested_field, nested_messages = message
          next generate_codes(nested_field, nested_messages)
        end
        field.to_s + "_" + message.to_s.remove("'").parameterize("_")
      end
    end
  end
end
