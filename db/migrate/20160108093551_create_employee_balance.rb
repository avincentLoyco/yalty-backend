class CreateEmployeeBalance < ActiveRecord::Migration
  def up
    create_table :employee_balances, id: :uuid do |t|
      t.integer :balance, default: 0
      t.integer :amount, default: 0
      t.uuid :time_off_id
      t.uuid :employee_id, null: false
      t.uuid :time_off_category_id, null: false
    end
    add_foreign_key :employee_balances, :employees, on_delete: :cascade, column: :employee_id
    add_foreign_key :employee_balances, :time_off_categories, column: :time_off_category_id
    add_foreign_key :employee_balances, :time_offs, column: :time_off_id

    add_index :employee_balances, :employee_id
    add_index :employee_balances, :time_off_category_id
    add_index :employee_balances, :time_off_id
  end

  def down
    drop_table :employee_balances
  end
end
