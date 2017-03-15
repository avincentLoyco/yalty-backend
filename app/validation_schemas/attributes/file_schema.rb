module Attributes
  module FileSchema
    def file_schema
      Dry::Validation.Form do
        required(:value).maybe(:str?)
      end
    end
  end
end
