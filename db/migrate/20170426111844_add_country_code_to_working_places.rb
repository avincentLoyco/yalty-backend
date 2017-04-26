class AddCountryCodeToWorkingPlaces < ActiveRecord::Migration
  def change
    add_column :working_places, :country_code, :string

    WorkingPlace.find_each do |wp|
      wp.country_code = wp.send(:country_data, wp.country)&.alpha2&.downcase
      wp.country = wp.send(:country_data, wp.country)&.name
      wp.save!
    end
  end
end
