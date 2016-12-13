module WorkingPlaceSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:name).filled(:str?)
      optional(:holiday_policy).maybe do
        schema do
          required(:id).filled(:str?)
        end
      end
      required(:country).filled(:str?)
      required(:city).filled(:str?)
      optional(:postalcode).maybe(:str?)
      optional(:additional_address).maybe(:str?)
      optional(:street).maybe(:str?)
      optional(:street_number).maybe(:str?)
    end
  end

  def put_schema
    Dry::Validation.Form do
      required(:id).filled(:str?)
      required(:name).filled(:str?)
      optional(:holiday_policy).maybe do
        schema do
          required(:id).filled(:str?)
        end
      end
      optional(:country).maybe(:str?)
      optional(:city).maybe(:str?)
      optional(:postalcode).maybe(:str?)
      optional(:additional_address).maybe(:str?)
      optional(:street).maybe(:str?)
      optional(:street_number).maybe(:str?)
    end
  end
end
