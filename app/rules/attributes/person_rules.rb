module Attributes
  module PersonRules
    def person_rules
      return unless value[:value].is_a?(Hash)
      Gate.rules do
        required :value, allow_nil: true do
          optional :lastname, allow_nil: true
          optional :firstname, allow_nil: true
          optional :gender, allow_nil: true
          optional :birthdate, allow_nil: true
        end
      end
    end
  end
end
