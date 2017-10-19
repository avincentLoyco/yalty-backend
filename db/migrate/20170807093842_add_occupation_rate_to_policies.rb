class AddOccupationRateToPolicies < ActiveRecord::Migration
  def change
    add_column :employee_time_off_policies, :occupation_rate, :float, null: false, default: 1.0
    add_column :employee_presence_policies, :occupation_rate, :float, null: false, default: 1.0
  end
end
