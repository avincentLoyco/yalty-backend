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
      optional(:country).maybe(:str?)
      optional(:city).maybe(:str?)
      optional(:state).maybe(:str?)
      optional(:postalcode).maybe(:str?)
      optional(:additional_address).maybe(:str?)
      optional(:street).maybe(:str?)
      optional(:street_number).maybe(:str?)

      rule(country_required: [
        :country, :street, :street_number, :additional_address, :postalcode, :city
      ]) do |country, street, street_number, additional_address, postalcode, city|
        (
          street.filled? | street_number.filled? | additional_address.filled? |
          postalcode.filled? | city.filled?
        ) > country.filled?
      end

      rule(state_required: [:state, :country]) do |state, country|
        (
          country.filled? &
          country.format?(/#{HolidayPolicy::COUNTRIES_WITH_REGIONS.join('|')}/i)
        ) > state.filled?
      end
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
      optional(:state).maybe(:str?)
      optional(:postalcode).maybe(:str?)
      optional(:additional_address).maybe(:str?)
      optional(:street).maybe(:str?)
      optional(:street_number).maybe(:str?)

      rule(country_required: [
        :country, :street, :street_number, :additional_address, :postalcode, :city
      ]) do |country, street, street_number, additional_address, postalcode, city|
        (
          street.filled? | street_number.filled? | additional_address.filled? |
          postalcode.filled? | city.filled?
        ) > country.filled?
      end

      rule(state_required: [:state, :country]) do |state, country|
        (
          country.filled? &
          country.format?(/#{HolidayPolicy::COUNTRIES_WITH_REGIONS.join('|')}/i)
        ) > state.filled?
      end
    end
  end
end
