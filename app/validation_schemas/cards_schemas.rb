module CardsSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:token).filled(:str?)
    end
  end
end
