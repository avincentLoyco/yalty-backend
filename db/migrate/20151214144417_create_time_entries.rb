class CreateTimeEntries < ActiveRecord::Migration
  def up
    create_table :time_entries, id: :uuid do |t|
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.uuid :presence_day_id, null: false
      t.timestamps null: false
    end
    add_foreign_key :time_entries, :presence_days, on_delete: :cascade, column: :presence_day_id
    add_index :time_entries, :presence_day_id
  end

  def down
    drop_table :time_entries
  end
end
