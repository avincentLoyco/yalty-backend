module Attribute
  class Number < Attribute::Base
    attribute :number, BigDecimal

    MAX_DB_INTEGER = 2**32
    MIN_DB_INTEGER = -MAX_DB_INTEGER

    def validate_range(range)
      rate = attributes.except(:attribute_type, *optional_attributes).values.first
      return if (true if Float(rate) rescue false) && rate.to_f.between?(range.first, range.last)
      errors.add("occupation_rate", "invalid value")
    end

    def validate_integer(additional_validation)
      return if additional_validation.try(:[], "allow_nil").eql?(true)
      return if Integer(number).between?(MIN_DB_INTEGER, MAX_DB_INTEGER)
      errors.add("value", "out of range")
    rescue TypeError, ArgumentError
      errors.add("value", "invalid value")
    end
  end
end
