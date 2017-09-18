class ChangeOccupationRateForPresencePolicy < ActiveRecord::Migration
  def change
    add_column :presence_policies, :occupation_rate, :float, null: false, default: 1.0
    remove_column :employee_presence_policies, :occupation_rate
  end
end
