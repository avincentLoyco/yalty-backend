class CreateTimeOff < ActiveRecord::Migration
  def up
    create_table :time_offs, id: :uuid do |t|
      t.datetime :end_time, null: false
      t.datetime :start_time, null: false
      t.uuid :time_off_category_id, null: false
      t.uuid :employee_id, null: false
      t.timestamps null: false
    end
    add_foreign_key :time_offs, :time_off_categories, column: :time_off_category_id
    add_foreign_key :time_offs, :employees, column: :employee_id, on_delete: :cascade
    add_index :time_offs, :employee_id
    add_index :time_offs, :time_off_category_id
  end

  def down
    drop_table :time_offs
  end
end
