class AddForeignKeyOnDeleteCascadeToHolidayPolicyOnAccount < ActiveRecord::Migration
  def up
    remove_foreign_key :holiday_policies, :accounts
    add_foreign_key :holiday_policies, :accounts, on_delete: :cascade
  end

  def down
    remove_foreign_key :holiday_policies, :accounts
    add_foreign_key :holiday_policies, :accounts
  end
end
