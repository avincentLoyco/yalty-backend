class AddActiveFlagToEmployeeEvent < ActiveRecord::Migration
  def change
    add_column :employee_events, :active, :bool
    change_column_null :employee_events, :active, false, true
    change_column_default :employee_events, :active, true
  end
end
