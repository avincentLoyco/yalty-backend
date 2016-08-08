module TimeOffPoliciesSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:name).filled(:str?)
      required(:start_day).filled(:int?)
      required(:start_month).filled(:int?)
      optional(:end_day).maybe(:int?)
      optional(:end_month).maybe(:int?)
      optional(:amount).maybe(:int?)
      optional(:years_to_effect).maybe(:int?)
      required(:policy_type).filled(:str?)
      required(:time_off_category).schema do
        required(:id).filled(:str?)
      end
    end
  end

  def put_schema
    Dry::Validation.Form do
      required(:id).filled(:str?)
      optional(:name).filled(:str?)
      required(:start_day).filled(:int?)
      required(:start_month).filled(:int?)
      optional(:end_day).maybe(:int?)
      optional(:end_month).maybe(:int?)
      optional(:amount).maybe(:int?)
      optional(:years_to_effect).maybe(:int?)
      required(:policy_type).filled(:str?)
    end
  end
end
