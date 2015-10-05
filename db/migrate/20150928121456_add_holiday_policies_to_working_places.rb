class AddHolidayPoliciesToWorkingPlaces < ActiveRecord::Migration
  def change
    add_column :working_places, :holiday_policy_id, :uuid, index: true, foreign_key: true
  end
end
