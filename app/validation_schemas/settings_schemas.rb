module SettingsSchemas
  include BaseSchemas

  def patch_schema
    Dry::Validation.Form do
      optional(:subdomain).filled(:str?)
      optional(:company_name).filled(:str?)
      optional(:timezone).filled(:str?)
      optional(:default_locale).filled(:str?)
      optional(:holiday_policy).maybe do
        schema do
          required(:id).filled(:str?)
        end
      end
    end
  end

  def put_schema
    Dry::Validation.Form do
      required(:subdomain).filled(:str?)
      required(:company_name).filled(:str?)
      optional(:timezone).filled(:str?)
      optional(:default_locale).filled(:str?)
      optional(:holiday_policy).maybe do
        schema do
          required(:id).filled(:str?)
        end
      end
    end
  end
end
