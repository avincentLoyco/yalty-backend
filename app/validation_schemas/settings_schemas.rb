module SettingsSchemas
  include BaseSchemas

  def patch_schema
    Dry::Validation.Form do
      optional(:subdomain).filled(:str?)
      optional(:company_name).filled(:str?)
      optional(:yalty_access).filled(:bool?)
      optional(:timezone).filled(:str?)
      optional(:default_locale).filled(:str?)
      optional(:company_information).filled(:hash?) do
        schema do
          required(:company_name).maybe(:str?)
          required(:address_1).maybe(:str?)
          required(:address_2).maybe(:str?)
          required(:city).maybe(:str?)
          required(:postalcode).maybe(:str?)
          required(:country).maybe(:str?)
          required(:region).maybe(:str?)
          required(:phone).maybe(:str?)
        end
      end
    end
  end

  def put_schema
    Dry::Validation.Form do
      required(:subdomain).filled(:str?)
      required(:company_name).filled(:str?)
      optional(:yalty_access).filled(:bool?)
      optional(:timezone).filled(:str?)
      optional(:default_locale).filled(:str?)
      optional(:company_information).filled(:hash?) do
        schema do
          required(:company_name).maybe(:str?)
          required(:address_1).maybe(:str?)
          required(:address_2).maybe(:str?)
          required(:city).maybe(:str?)
          required(:postalcode).maybe(:str?)
          required(:country).maybe(:str?)
          required(:region).maybe(:str?)
          required(:phone).maybe(:str?)
        end
      end
    end
  end
end
