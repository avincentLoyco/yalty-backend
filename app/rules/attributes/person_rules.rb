module Attributes
  module PersonRules
    def person_rules
      return unless value[:value].is_a?(Hash)
      Gate.rules do
        required :value, allow_nil: true do
          optional :lastname
          optional :firstname
          optional :gender
          optional :birthdate
        end
      end
    end
  end
end
