class AddHolidayPolicyToEmployees < ActiveRecord::Migration
  def change
    add_column :employees, :holiday_policy, :uuid, index: true, foreign_key: true
  end
end
