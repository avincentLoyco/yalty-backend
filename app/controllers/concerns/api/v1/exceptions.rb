module API
  module V1
    module Exceptions
      class Forbidden <StandardError
        def initialize(data)
          super
          @data = data
        end
      end
    end
  end
end
