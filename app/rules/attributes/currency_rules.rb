module Attributes
  module CurrencyRules
    def currency_rules
      return unless value[:value].is_a?(Hash)
      Gate.rules do
        required :value, :Hash, allow_nil: true do
          optional :amount, :Decimal, allow_nil: true
          optional :isocode, :String, allow_nil: true
        end
      end
    end
  end
end
