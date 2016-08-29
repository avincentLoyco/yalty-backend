module Attributes
  module DateSchema
    def date_schema
      Dry::Validation.Form do
        required(:value).maybe
      end
    end
  end
end
