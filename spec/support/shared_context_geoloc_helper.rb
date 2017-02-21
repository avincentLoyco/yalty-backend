RSpec.shared_context 'shared_context_geoloc_helper' do
  before do
    allow_any_instance_of(WorkingPlace).to receive(:location_attributes) do
      loc = Geokit::GeoLoc.new(city: city)
      loc.state_name = state_name
      loc.state_code = state_code
      loc.country = country
      loc.country_code = country_code
      loc.success = [city, state_name, country].all?(&:present?)
      loc
    end
    allow_any_instance_of(WorkingPlace).to receive(:location_timezone) do
      Timezone::Zone.new(timezone)
    end
  end

  let(:city) { 'Zurich' }
  let(:country) { 'Switzerland' }
  let(:country_code) { 'CH' }
  let(:state_name) { 'Zurich' }
  let(:state_code) { 'ZH' }
  let(:timezone) { 'Europe/Zurich' }
end
