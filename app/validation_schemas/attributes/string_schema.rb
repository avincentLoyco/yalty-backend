module Attributes
  module StringSchema
    def string_schema
      Dry::Validation.Form do
        required(:value).maybe(:str?)
      end
    end
  end
end
