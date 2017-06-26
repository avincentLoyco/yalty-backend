module SubscriptionsSchemas
  include BaseSchemas

  def settings_schema
    Dry::Validation.Form do
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
      optional(:emails).maybe { array? { each { str? } } }
    end
  end
end
