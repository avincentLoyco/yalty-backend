module PresencePolicySchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:name).filled(:str?)
      required(:occupation_rate).filled(:float?)
      optional(:presence_days).maybe(:array?)
      optional(:standard_day_duration).maybe(:int?)
    end
  end

  def put_schema
    Dry::Validation.Form do
      required(:id).filled(:str?)
      required(:name).filled(:str?)
      optional(:occupation_rate).filled(:float?)
      optional(:standard_day_duration).maybe(:int?)
    end
  end
end
