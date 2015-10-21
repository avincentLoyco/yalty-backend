module API
  module V1
    module Exceptions
      class MissingOrInvalidData < StandardError 
        def initialize(data)
          super 
          @data = data
        end
      end
    end
  end
end
