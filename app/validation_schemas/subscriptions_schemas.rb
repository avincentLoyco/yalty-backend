module SubscriptionsSchemas
  include BaseSchemas

  def settings_schema
    Dry::Validation.Form do
      optional(:company_information).maybe do
        schema do
          required(:company_name).filled(:str?)
          required(:street).filled(:str?)
          required(:city).filled(:str?)
          required(:postalcode).filled(:str?)
          required(:country).filled(:str?)
          required(:region).filled(:str?)
          optional(:additional_address).filled(:str?)
        end
      end
      optional(:emails).maybe(:array?)
    end
  end
end
