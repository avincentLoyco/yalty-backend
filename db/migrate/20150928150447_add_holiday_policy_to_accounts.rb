class AddHolidayPolicyToAccounts < ActiveRecord::Migration
  def change
    add_column :accounts, :holiday_policy_id, :uuid, index: true, foreign_key: true
  end
end
