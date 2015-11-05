class AddForeignKeyToWorkingPlaceToPresencePolicy < ActiveRecord::Migration
  def up
    add_foreign_key :working_places, :presence_policies, column: :presence_policy_id
  end

  def down
    remove_foreign_key :working_places, column: :presence_policy_id
  end
end
