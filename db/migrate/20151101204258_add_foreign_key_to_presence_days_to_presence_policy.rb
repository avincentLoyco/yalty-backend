class AddForeignKeyToPresenceDaysToPresencePolicy < ActiveRecord::Migration
  def up
    add_foreign_key :presence_days, :presence_policies, column: :presence_policy_id, on_delete: :cascade
  end

  def down
    remove_foreign_key :presence_days, column: :presence_policy_id
  end
end
