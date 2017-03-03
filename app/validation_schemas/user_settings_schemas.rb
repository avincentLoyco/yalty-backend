module UserSettingsSchemas
  include BaseSchemas

  def put_schema
    Dry::Validation.Form do
      required(:email).filled(:str?)
      required(:locale).maybe(:str?)
      optional(:password_params).schema do
        required(:old_password).filled(:str?)
        required(:password).filled(:str?)
        required(:password_confirmation).filled(:str?)
      end
    end
  end
end
