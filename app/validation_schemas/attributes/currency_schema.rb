module Attributes
  module CurrencySchema
    def currency_schema
      return unless value[:value].is_a?(Hash)
      Dry::Validation.Form do
        required(:value).maybe.schema do
          optional(:amount).maybe(:decimal?)
          optional(:isocode).maybe(:str?)
        end
      end
    end
  end
end
