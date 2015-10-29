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
        def initialize(resource, messages)
          @resource = resource
          @messages = messages
        end

        def resource
          @resource
        end

        def messages
          @messages
        end
      end
    end
  end
end
