module Attribute
  class Child < Attribute::Base
    inherited Attribute::Person

    attribute :mother_is_working, Boolean
    attribute :is_student, Boolean
  end
end
