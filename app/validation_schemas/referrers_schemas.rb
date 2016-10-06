module ReferrersSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:email).filled(:str?)
    end
  end

  def referrers_csv_schema
    Dry::Validation.Form do
      optional(:from).filled(:date?)
      optional(:to).filled(:date?)
    end
  end
end
