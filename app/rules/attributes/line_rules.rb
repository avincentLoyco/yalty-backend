module Attributes
  module LineRules
    def line_rules
      Gate.rules do
        required :value, :String, allow_nil: true
      end
    end
  end
end
