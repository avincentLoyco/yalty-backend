class AddResetFlagToPoliciesAndWorkingPlaces < ActiveRecord::Migration
  def change
    add_column :working_places,    :reset, :boolean, default: false
    add_column :presence_policies, :reset, :boolean, default: false
    add_column :time_off_policies, :reset, :boolean, default: false
  end
end
