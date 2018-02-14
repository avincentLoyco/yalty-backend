module PresencePolicySchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:name).filled(:str?)
      required(:occupation_rate).filled(:float?)
      required(:standard_day_duration).filled(:int?)
      optional(:presence_days).maybe(:array?)
      optional(:default_full_time).filled(:bool?)
    end
  end

  def put_schema
    Dry::Validation.Form do
      required(:id).filled(:str?)
      required(:name).filled(:str?)
      required(:standard_day_duration).filled(:int?)
      optional(:occupation_rate).filled(:float?)
      optional(:default_full_time).filled(:bool?)
    end
  end
end
