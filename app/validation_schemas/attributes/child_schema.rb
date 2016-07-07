module Attributes
  module ChildSchema
    def child_schema
      return unless value[:value].is_a?(Hash)
      Dry::Validation.Form do
        required(:value).maybe.schema do
          optional(:mother_is_working).maybe(:bool?)
          optional(:is_student).maybe(:bool?)
          optional(:lastname).maybe(:str?)
          optional(:firstname).maybe(:str?)
          optional(:gender).maybe(:str?)
          optional(:birthdate).maybe(:str?)
        end
      end
    end
  end
end
