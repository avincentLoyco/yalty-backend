module Attributes
  module DateRules
    def date_rules
      Gate.rules do
        required :value, allow_nil: true
      end
    end
  end
end
