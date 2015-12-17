module Attribute
  class Currency < Attribute::Base
    attribute :amount, String
    attribute :isocode, String
  end
end
