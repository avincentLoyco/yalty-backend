module UserSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:email).filled(:str?)
      optional(:password).filled(:str?)
      optional(:role).filled(:str?)
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
      optional(:email).filled(:str?)
      optional(:password).filled(:str?)
      optional(:role).filled(:str?)
      optional(:employee).maybe do
        schema do
          required(:id).filled(:str?)
        end
      end
    end
  end
end
