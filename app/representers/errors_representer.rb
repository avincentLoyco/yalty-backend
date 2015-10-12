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

    if resource.kind_of?(ActiveRecord::Base) && !resource.errors.empty?
      errors = resource.errors.messages.map do |field, message|
        {
          field: field.to_s,
          messages: message,
          status: 'invalid',
          type: resource_type,
        }
      end

      response[:errors] = errors
    end

    response.merge(basic)
  end
end
