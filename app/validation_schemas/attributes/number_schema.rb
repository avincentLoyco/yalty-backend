module Attributes
  module NumberSchema
    def number_schema
      Dry::Validation.Form do
        required(:value).maybe(:decimal?)
      end
    end
  end
end
