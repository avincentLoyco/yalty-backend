class ChangeOccupationRateForPresencePolicy < ActiveRecord::Migration
  def change
    add_column :presence_policies, :occupation_rate, :float, null: false
    change_column_default(:presence_policies, :occupation_rate, 1.0)
    remove_column :employee_presence_policies, :occupation_rate
  end
end
