module Attribute
  class Person < Attribute::Base
    attribute :lastname, String
    attribute :firstname, String
    attribute :birthdate, DateTime
    attribute :gender, String
  end
end
