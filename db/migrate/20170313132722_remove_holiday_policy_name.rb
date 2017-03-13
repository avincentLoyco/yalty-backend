class RemoveHolidayPolicyName < ActiveRecord::Migration
  def change
    remove_column :holiday_policies, :name
  end
end
