module AccountSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:account).schema do
        required(:company_name).filled
        optional(:default_locale).maybe
        optional(:referred_by).maybe(:str?)
      end
      required(:user).schema do
        required(:email).filled
      end
    end
  end
end
