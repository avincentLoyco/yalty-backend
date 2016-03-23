module Api::V1
  class ErrorsRepresenter < BaseRepresenter
    attr_reader :resource, :messages

    def initialize(resource, messages = nil)
      super(resource)
      @messages = messages
    end

    def complete
      response = {}
      if @messages.blank?
        @messages = if resource.is_a?(ActiveRecord::Base)
                      resource.errors.messages
                    elsif resource.is_a?(Gate::Result)
                      resource.errors
                    elsif resource.is_a?(Struct)
                      resource.errors
                    else
                      []
                    end
      end

      errors = @messages.map do |field, message|
        {
          field: field.to_s,
          messages: message,
          status: 'invalid',
          type: resource_type
        }
      end

      response[:errors] = errors
      response
    end
  end
end
