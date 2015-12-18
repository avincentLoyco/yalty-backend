module Attributes
  module ChildRules
    def child_rules
      return unless value[:value].is_a?(Hash)
      Gate.rules do
        required :value, allow_nil: true do
          optional :mother_is_working, :Boolean, allow_nil: true
          optional :is_student, :Boolean, allow_nil: true
          optional :lastname, :String, allow_nil: true
          optional :firstname, :String, allow_nil: true
          optional :gender, :String, allow_nil: true
          optional :birthdate, :String, allow_nil: true
        end
      end
    end
  end
end
