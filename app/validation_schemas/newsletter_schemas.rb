module NewsletterSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:email).filled(:str?)
      required(:name).filled(:str?)
      optional(:language).filled(:str?)
    end
  end
end
