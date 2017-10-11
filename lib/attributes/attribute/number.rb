module Attribute
  class Number < Attribute::Base
    attribute :number, BigDecimal

    def validate_range(range)
      rate = attributes.except(:attribute_type, *optional_attributes).values.first
      return if (true if Float(rate) rescue false) && rate.to_f.between?(range.first, range.last)
      errors.add('occupation_rate', 'invalid value')
    end
  end
end
