class AddOccupationRateToPolicies < ActiveRecord::Migration
  def change
    add_column :employee_time_off_policies, :occupation_rate, :float, null: false
    change_column_default(:employee_time_off_policies, :occupation_rate, 1.0)
    add_column :employee_presence_policies, :occupation_rate, :float, null: false
    change_column_default(:employee_presence_policies, :occupation_rate, 1.0)
  end
end
