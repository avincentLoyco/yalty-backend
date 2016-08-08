module Attributes
  module PersonSchema
    def person_schema
      return unless value[:value].is_a?(Hash)
      Dry::Validation.Form do
        required(:value).maybe.schema do
          optional(:lastname).maybe
          optional(:firstname).maybe
          optional(:gender).maybe
          optional(:birthdate).maybe
        end
      end
    end
  end
end
