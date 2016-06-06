class RemoveWorkingPlaceIdFromEmployee < ActiveRecord::Migration
  def change
    remove_column :employees, :working_place_id
  end
end
