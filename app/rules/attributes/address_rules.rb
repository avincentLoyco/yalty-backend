module Attributes
  module AddressRules
    def address_rules
      return unless value[:value].is_a?(Hash)
      Gate.rules do
        required :value, allow_nil: true do
          optional :street, :String, allow_nil: true
          optional :streetno, :String, allow_nil: true
          optional :postalcode, :String, allow_nil: true
          optional :city, :String, allow_nil: true
          optional :region, :String, allow_nil: true
          optional :country, :String, allow_nil: true
        end
      end
    end
  end
end
