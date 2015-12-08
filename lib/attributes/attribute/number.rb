module Attribute
  class Number < Attribute::Base
    attribute :number, BigDecimal

    validates :number, presence: true
  end
end
