module Attribute
  class Number < Attribute::Base
    attribute :number, BigDecimal

    def self.ruby_type
      'BigDecimal'
    end
  end
end
