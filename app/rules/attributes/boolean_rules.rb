module Attributes
  module BooleanRules
    def boolean_rules
      Gate.rules do
        required :value, :Boolean, allow_nil: true
      end
    end
  end
end
