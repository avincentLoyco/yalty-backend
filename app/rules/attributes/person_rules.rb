module Attributes
  module PersonRules
    def person_rules
      Gate.rules do
        required :value do
          optional :lastname
          optional :firstname
          optional :gender
          optional :birthdate
        end
      end
    end
  end
end
