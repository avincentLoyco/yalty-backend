class AddActiveFlagToEmployeeEvent < ActiveRecord::Migration
  def change
    add_column :employee_events, :active, :bool, null: false, default: true
  end
end
