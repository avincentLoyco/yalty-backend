RSpec.shared_context 'shared_context_geoloc_helper' do
  def geoloc_instance(attributes)
    if !(%i(city state_name state_code country country_code) - attributes.keys).empty?
      raise ArgumentError, 'should include all attributes'
    end

    loc = Geokit::GeoLoc.new(city: attributes[:city])
    loc.state_name = attributes[:state_name]
    loc.state_code = attributes[:state_code]
    loc.country = attributes[:country]
    loc.country_code = attributes[:country_code]
    loc
  end

  before do
    allow_any_instance_of(WorkingPlace).to receive(:location_attributes) do
      geoloc_instance(
        city: city,
        state_name: state_name,
        state_code: state_code,
        country: country,
        country_code: country_code,
      )
    end

    allow_any_instance_of(WorkingPlace).to receive(:location_timezone) do
      Timezone::Zone.new(timezone)
    end
  end

  let(:city) { nil }
  let(:state_name) { 'Zurich' }
  let(:state_code) { 'ZH' }
  let(:country) { 'Switzerland' }
  let(:country_code) { 'CH' }
  let(:timezone) { 'Europe/Zurich' }
end
