module PresencePolicySchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:name).filled(:str?)
      optional(:presence_days).maybe(:array?)
    end
  end

  def put_schema
    Dry::Validation.Form do
      required(:id).filled(:str?)
      required(:name).filled(:str?)
    end
  end
end
