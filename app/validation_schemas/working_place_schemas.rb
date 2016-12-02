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
      optional(:state).filled(:str?)
      required(:city).filled(:str?)
      optional(:postalcode).filled(:str?)
      optional(:additional_address).filled(:str?)
      optional(:street).filled(:str?)
      optional(:street_number).filled(:str?)
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
      optional(:country).filled(:str?)
      optional(:state).filled(:str?)
      optional(:city).filled(:str?)
      optional(:postalcode).filled(:str?)
      optional(:additional_address).filled(:str?)
      optional(:street).filled(:str?)
    end
  end
end
