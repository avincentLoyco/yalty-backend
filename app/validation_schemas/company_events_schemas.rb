module CompanyEventsSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:title).filled(:str?)
      required(:effective_at).filled(:date?)
      optional(:comment).filled(:str?)
      optional(:files).each do
        schema do
          required(:id).filled(:str?)
          required(:type).filled(:str?)
          required(:original_filename).filled(:str?)
        end
      end
    end
  end

  def put_schema
    Dry::Validation.Form do
      required(:id).filled(:str?)
      optional(:title).filled(:str?)
      optional(:effective_at).filled(:date?)
      optional(:comment).filled(:str?)
      optional(:files).each do
        schema do
          required(:id).filled(:str?)
          required(:type).filled(:str?)
          required(:original_filename).filled(:str?)
        end
      end
    end
  end
end
