module Attributes
  module LineSchema
    def line_schema
      Dry::Validation.Form do
        required(:value).maybe(:str?)
      end
    end
  end
end
