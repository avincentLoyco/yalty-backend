module Attribute
  class Currency < Attribute::Base
    attribute :amount, BigDecimal
    attribute :isocode, String
  end
end
