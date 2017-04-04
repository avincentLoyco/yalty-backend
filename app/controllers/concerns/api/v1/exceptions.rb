module API
  module V1
    module Exceptions
      class MissingOrInvalidData < StandardError
        def initialize(data)
          super
          @data = data
        end
      end

      class InvalidResourcesError < StandardError
        attr_reader :resource, :messages

        def initialize(resource, messages)
          @resource = resource
          @messages = messages
        end
      end

      class InvalidPasswordError < StandardError
        attr_reader :resource, :message

        def initialize(resource, message)
          @resource = resource
          @message = message
        end
      end

      class EventTypeNotFoundError < StandardError
        attr_reader :resource, :message

        def initialize(resource, message)
          @resource = resource
          @message = message
        end
      end

      class InvalidParamTypeError < StandardError
        attr_reader :resource, :message

        def initialize(resource, message)
          @resource = resource
          @message = message
        end
      end

      class BaseError < StandardError
        attr_reader :type, :field, :message, :code

        def initialize(type:, field:, message:, code:)
          @type = type
          @field = field
          @message = message
          @code = code
        end
      end

      class CustomerNotCreated < BaseError
        def initialize
          super(
            type: 'account',
            field: 'customer_id',
            message: 'Customer is not created',
            code: 'required_field'
          )
        end
      end

      class StripeError < BaseError
        def initialize(type:, field:, message:, code: 'proxy_gateway_error')
          super
        end
      end
    end
  end
end
