task update_empty_working_place_coordinate: [:environment] do
  WorkingPlace.where(country: nil)
              .where.not(holiday_policy_id: nil)
              .includes(:holiday_policy).each do |wp|
    hp = wp.holiday_policy
    location =
      Geokit::Geocoders::GoogleGeocoder.geocode("#{hp.region}, #{hp.country}")

    wp.state = location.state
    wp.country = location.country
    wp.save!
  end
end
