class AddEventTypeToEvents < ActiveRecord::Migration
  def change
    add_column :employee_events, :event_type, :string, null: true
    change_column_null :employee_events, :event_type, false, 'hired'
  end
end
