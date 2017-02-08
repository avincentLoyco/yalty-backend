RSpec.shared_context 'shared_context_geoloc_helper' do
  before do
    allow_any_instance_of(WorkingPlace).to receive(:location_attributes) do
      loc = Geokit::GeoLoc.new(city: city)
      loc.country = country
      loc.country_code = country_code
      loc.state_code = state_code
      loc.state_name = state_name
      loc
    end
    allow_any_instance_of(WorkingPlace).to receive(:location_timezone) { timezone }
  end

  let(:city) { 'Zurich' }
  let(:country) { 'Switzerland' }
  let(:country_code) { 'CH' }
  let(:state_name) { 'Zurich' }
  let(:state_code) { 'ZH' }
  let(:timezone) { 'Europe/Zurich' }
end
