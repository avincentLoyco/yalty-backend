module TokensSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      optional(:file_id).filled(:str?)
      optional(:duration).filled(:str?)
      optional(:version).filled(:str?).value(included_in?: %w(original thumbnail))
    end
  end
end
