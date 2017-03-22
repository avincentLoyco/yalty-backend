module Attribute
  class Person < Attribute::Base
    attribute :lastname, String
    attribute :firstname, String
    attribute :birthdate, DateTime
    attribute :gender, String
    attribute :nationality, String
    attribute :permit_type, String
    attribute :avs_number, String
    attribute :permit_expiry, DateTime
  end
end
