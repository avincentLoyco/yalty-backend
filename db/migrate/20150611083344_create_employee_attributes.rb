class CreateEmployeeAttributes < ActiveRecord::Migration
  def change
    create_table :employee_attributes do |t|
      t.string :name, null: false
      t.hstore :data
      t.string :type, null: false
      t.references :employee, index: true, foreign_key: { on_delete: :cascade }

      t.timestamps null: false
    end
  end
end
