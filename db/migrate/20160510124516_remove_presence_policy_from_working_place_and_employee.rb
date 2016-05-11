class RemovePresencePolicyFromWorkingPlaceAndEmployee < ActiveRecord::Migration
  def change
    remove_column :working_places, :presence_policy_id
    remove_column :employees, :presence_policy_id
  end
end
