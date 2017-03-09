module WorkingPlaceSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:name).filled(:str?)
      optional(:country).maybe(:str?)
      optional(:city).maybe(:str?)
      optional(:state).maybe(:str?)
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
      optional(:country).maybe(:str?)
      optional(:city).maybe(:str?)
      optional(:state).maybe(:str?)
      optional(:postalcode).maybe(:str?)
      optional(:additional_address).maybe(:str?)
      optional(:street).maybe(:str?)
      optional(:street_number).maybe(:str?)
    end
  end
end
