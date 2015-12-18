module Attributes
  module CurrencyRules
    def currency_rules
      Gate.rules do
        required :value, :String, allow_nil: true
      end
    end
  end
end
