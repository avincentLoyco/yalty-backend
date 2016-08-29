module Attributes
  module BooleanSchema
    def boolean_schema
      Dry::Validation.Form do
        required(:value).maybe(:bool?)
      end
    end
  end
end
