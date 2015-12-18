module Attributes
  module AddressRules
    def address_rules
      return unless value[:value].is_a?(Hash) || value[:value].is_a?(NilClass)
      Gate.rules do
        required :value, allow_nil: true do
          optional :street, :String
          optional :streetno, :String
          optional :postalcode, :String
          optional :city, :String
          optional :region, :String
          optional :country, :String
        end
      end
    end
  end
end
