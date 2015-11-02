class AddForeignKeyToEmployeeToPresencePolicy < ActiveRecord::Migration
  def up
    add_foreign_key :employees, :presence_policies, column: :presence_policy_id
  end

  def down
    remove_foreign_key :employees, column: :presence_policy_id
  end
end
