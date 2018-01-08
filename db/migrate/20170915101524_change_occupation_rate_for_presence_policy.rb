class ChangeOccupationRateForPresencePolicy < ActiveRecord::Migration
  def change
    add_column :presence_policies, :occupation_rate, :float
    change_column_null :presence_policies, :occupation_rate, false, 1.0
    change_column_default :presence_policies, :occupation_rate, 1.0
    remove_column :employee_presence_policies, :occupation_rate
  end
end
