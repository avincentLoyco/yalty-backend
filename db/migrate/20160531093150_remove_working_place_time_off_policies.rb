class RemoveWorkingPlaceTimeOffPolicies < ActiveRecord::Migration
  def change
    drop_table :working_place_time_off_policies
  end
end
