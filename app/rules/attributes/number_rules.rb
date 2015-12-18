module Attributes
  module NumberRules
    def number_rules
      Gate.rules do
        required :value, :Decimal, allow_nil: true
      end
    end
  end
end
