class AddCountryCodeToWorkingPlaces < ActiveRecord::Migration
  def change
    add_column :working_places, :country_code, :string
  end
end
