Geokit::Geocoders::GoogleGeocoder.api_key = ENV['GOOGLE_GEOCODERS']
Timezone::Lookup.config(:geonames) do |c|
  c.username = ENV['GEONAMES_KEY']
end
