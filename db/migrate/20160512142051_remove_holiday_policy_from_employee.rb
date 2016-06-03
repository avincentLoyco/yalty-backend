class RemoveHolidayPolicyFromEmployee < ActiveRecord::Migration
  def change
    remove_column :employees, :holiday_policy_id
  end
end
