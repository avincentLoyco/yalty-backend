module Attribute
  class Person < Attribute::Base
    attribute :lastname, String
    attribute :firstname, String
    attribute :birthdate, DateTime
    attribute :gender, String

    def self.ruby_type
      'Hash'
    end
  end
end
