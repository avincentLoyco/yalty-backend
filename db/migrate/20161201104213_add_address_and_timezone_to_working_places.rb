class AddAddressAndTimezoneToWorkingPlaces < ActiveRecord::Migration
  def change
    add_column :working_places, :country, :string, limit: 60
    add_column :working_places, :state, :string, limit: 60
    add_column :working_places, :city, :string, limit: 60
    add_column :working_places, :postalcode, :string, limit: 12
    add_column :working_places, :additional_address, :string, limit: 60
    add_column :working_places, :street, :string, limit: 60
    add_column :working_places, :street_number, :string, limit: 10
    add_column :working_places, :timezone, :string
  end
end
