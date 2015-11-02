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
    end
  end
end
