class CreateEmployeeAttributeDefinitions < ActiveRecord::Migration
  def change
    create_table :employee_attribute_definitions do |t|
      t.string :name, null: false
      t.string :label, null: false
      t.boolean :system, null: false, default: false
      t.string :attribute_type, null: false
      t.hstore :validation
      t.references :account, index: true, foreign_key: { on_delete: :cascade }, null: false

      t.timestamps null: false
    end

    add_index :employee_attribute_definitions, [:name, :account_id], unique: true
  end
end
