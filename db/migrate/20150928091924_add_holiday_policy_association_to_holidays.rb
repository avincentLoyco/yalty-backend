class AddHolidayPolicyAssociationToHolidays < ActiveRecord::Migration
  def up
    add_column :holidays, :holiday_policy_id, :uuid, null: false
  end

  def down
    remove_column :holidays, :holiday_policy_id
  end
end
