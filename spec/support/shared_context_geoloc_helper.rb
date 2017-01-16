RSpec.shared_context 'shared_context_geoloc_helper' do
  before do
    allow_any_instance_of(WorkingPlace).to receive(:location_attributes) do
      loc = Geokit::GeoLoc.new(city: city)
      loc.country = country
      loc.country_code = country_code
      loc.state_code = state_code
      loc
    end
    allow_any_instance_of(WorkingPlace).to receive(:location_timezone) { 'Europe/Zurich' }
  end

  let(:city) { 'Zurich' }
  let(:country) { 'Switzerland' }
  let(:country_code) { 'ch' }
  let(:state_code) { 'zh' }
end
