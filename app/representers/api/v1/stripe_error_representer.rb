module Api
  module V1
    class StripeErrorRepresenter < BaseRepresenter
      def initialize(exception)
        @exception = exception
      end

      def complete
        {
          errors: [
            {
              type: @exception.type,
              message: @exception.message,
              field: @exception.field,
              code:  @exception.code
            }
          ]
        }
      end
    end
  end
end
