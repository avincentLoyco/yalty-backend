class ErrorsRepresenter
  attr_accessor :messages, :type

  def initialize(messages, type)
    @messages = messages
    @type = type
  end

  def resource
    {
      errors: messages.map do |key, value|
        {
          field: key.to_s,
          messages: value,
          status: 'invalid',
          type: type,
        }
      end
    }

  end
end
