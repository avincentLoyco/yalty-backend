module Attribute
  class Address < Attribute::Base
    attribute :street, String
    attribute :streetno, String
    attribute :postalcode, String
    attribute :city, String
    attribute :region, String
    attribute :country, String
  end
end
