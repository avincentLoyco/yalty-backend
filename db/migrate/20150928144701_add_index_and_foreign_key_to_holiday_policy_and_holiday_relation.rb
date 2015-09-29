class AddIndexAndForeignKeyToHolidayPolicyAndHolidayRelation < ActiveRecord::Migration
  def up
    add_foreign_key :holidays, :holiday_policies, column: :holiday_policy_id, on_delete: :cascade
    add_index :holidays, :holiday_policy_id
  end

  def down
    remove_foreign_key :holidays, :holiday_policies
    remove_index :holidays, :holiday_policy_id
  end
end
