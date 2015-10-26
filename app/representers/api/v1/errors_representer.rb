module Api::V1
  class ErrorsRepresenter < BaseRepresenter
    attr_reader :message

    def initialize(message, resource = nil)
      super(resource)

      @message = message
    end

    def basic(_ = {})
      {
        status: 'error',
        message: message
      }
    end

    def complete
      response = {}

      if resource.is_a?(ActiveRecord::Base)
        messages = resource.errors.messages
      elsif resource.is_a?(Gate::Result)
        messages = resource.errors
      else
        messages = []
      end

      errors = messages.map do |field, message|
        {
          field: field.to_s,
          messages: message,
          status: 'invalid',
          type: resource_type
        }
      end

      response[:errors] = errors unless errors.empty?
      response.merge(basic)
    end
  end
end
