module UserSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:email).filled(:str?)
      required(:locale).maybe(:str?)
      optional(:role).maybe(:str?)
      optional(:password_params).schema do
        optional(:old_password).filled(:str?)
        required(:password).filled(:str?)
        required(:password_confirmation).filled(:str?)
      end
      optional(:employee).maybe do
        schema do
          required(:id).filled(:str?)
        end
      end
    end
  end

  def put_schema
    Dry::Validation.Form do
      required(:id).filled(:str?)
      required(:email).filled(:str?)
      required(:locale).maybe(:str?)
      optional(:role).filled(:str?)
      optional(:password_params).schema do
        optional(:old_password).filled(:str?)
        required(:password).filled(:str?)
        required(:password_confirmation).filled(:str?)
      end
      optional(:employee).maybe do
        schema do
          required(:id).filled(:str?)
        end
      end
    end
  end
end
