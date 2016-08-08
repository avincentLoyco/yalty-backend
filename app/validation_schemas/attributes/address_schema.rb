module Attributes
  module AddressSchema
    def address_schema
      return unless value[:value].is_a?(Hash)
      Dry::Validation.Form do
        required(:value).maybe.schema do
          optional(:street).maybe(:str?)
          optional(:streetno).maybe(:str?)
          optional(:postalcode).maybe(:str?)
          optional(:city).maybe(:str?)
          optional(:region).maybe(:str?)
          optional(:country).maybe(:str?)
        end
      end
    end
  end
end
