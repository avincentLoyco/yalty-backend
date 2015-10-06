class ResourceErrorsRepresenter
  attr_accessor :messages, :type

  def initialize(messages, type)
    @messages = messages
    @type = type
  end

  def basic
    {
      errors: messages.map do |key, value|
        {
          field: key.to_s,
          messages: value,
          code: 'invalid',
          type: type,
        }
      end
    }

  end
end
