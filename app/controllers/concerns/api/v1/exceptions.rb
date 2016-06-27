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
    end
  end
end
