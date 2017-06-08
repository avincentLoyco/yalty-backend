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
          status: 'invalid',
          type: resource_type,
          codes: generate_codes(field, messages)
        }
      end

      response[:errors] = errors
      response
    end

    def generate_codes(field, messages)
      codes = []
      if messages
        messages.each do |message|
          if message && !message.is_a?(Array)
            message_without_apostrophes = message.gsub(/'/, "")
            message_with_underscores = message_without_apostrophes.gsub(" ", "_")
            codes << field.to_s + '_' + message_with_underscores.downcase
          end
        end
      end
      codes
    end

  end
end
