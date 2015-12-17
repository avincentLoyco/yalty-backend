module Attribute
  class Child < Person
    attribute :mother_is_working, Boolean
    attribute :is_student, Boolean

    def self.ruby_type
      'Hash'
    end
  end
end
