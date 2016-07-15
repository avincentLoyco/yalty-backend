class CreateRegisteredWorkingTime < ActiveRecord::Migration
  def change
    create_table :registered_working_times, id: :uuid do |t|
      t.uuid :employee_id, null: false
      t.boolean :schedule_generated, null: false, default: false
      t.date :date, null: false
      t.json :time_entries, default: {}, null: false
      t.timestamps null: false
    end

    add_foreign_key :registered_working_times, :employees
    add_index :registered_working_times, [:employee_id, :date], unique: true
  end
end
