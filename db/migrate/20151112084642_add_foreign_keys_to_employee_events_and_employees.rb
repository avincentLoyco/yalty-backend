class AddForeignKeysToEmployeeEventsAndEmployees < ActiveRecord::Migration
  def up
    add_foreign_key :employee_events, :employees, on_delete: :cascade
    add_foreign_key :employee_attribute_versions, :employee_events, on_delete: :cascade
  end

  def down
    remove_foreign_key :employee_events, :employees
    remove_foreign_key :employee_attribute_versions, :employee_events
  end
end
