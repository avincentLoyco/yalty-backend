class RemoveHolidayFromAccount < ActiveRecord::Migration
  def change
    remove_column :accounts, :holiday_policy_id
  end
end
