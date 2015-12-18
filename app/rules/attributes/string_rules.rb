module Attributes
  module StringRules
    def string_rules
      Gate.rules do
        required :value, :String, allow_nil: true
      end
    end
  end
end
