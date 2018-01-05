class AddActiveFlagToEmployeeEvent < ActiveRecord::Migration
  def change
    add_column :employee_events, :active, :bool, null: false
    change_column_default(:employee_events, :active, true)
  end
end
