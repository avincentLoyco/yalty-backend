class CreateWeeklyReports < ActiveRecord::Migration
  def change
    create_table :employee_weekly_reports do |t|
      t.uuid :employee_id, null: false
      t.date :date_from, null: false
      t.date :date_to, null: false
      t.float :worked, null: false
      t.float :planned, null: false
      t.float :bank_holidays, null: false
      t.float :absences, null: false
      t.float :difference, null: false
      t.integer :status, null: false
      t.integer :year, null: false
    end

    add_foreign_key :employee_weekly_reports, :employees, on_delete: :cascade, column: :employee_id

    add_index :employee_weekly_reports, :employee_id
    add_index :employee_weekly_reports, :year
  end
end
