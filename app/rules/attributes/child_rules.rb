module Attributes
  module ChildRules
    def child_rules
      return unless value[:value].is_a?(Hash) || value.is_a?(NilClass)
      Gate.rules do
        required :value, allow_nil: true do
          optional :mother_is_working, :Boolean
          optional :is_student, :Boolean
          optional :lastname, :String
          optional :firstname, :String
          optional :gender, :String
          optional :birthdate, :String
        end
      end
    end
  end
end
