module UserPasswordSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:email).filled(:str?)
    end
  end

  def put_schema
    Dry::Validation.Form do
      required(:reset_password_token).filled(:str?)
      required(:password).filled(:str?)
      required(:password_confirmation).filled(:str?)
    end
  end
end
