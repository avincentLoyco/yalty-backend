module TokensSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      optional(:file_id).filled(:str?)
      optional(:duration).filled(:str?)
    end
  end
end
