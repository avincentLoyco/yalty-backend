module Api::V1
  class CustomizedErrorRepresenter
    def initialize(exception)
      @exception = exception
    end

    def complete
      {
        errors: [
          {
            type: @exception.type,
            messages: @exception.messages,
            field: @exception.field,
            codes:  @exception.codes
          }
        ]
      }
    end
  end
end
