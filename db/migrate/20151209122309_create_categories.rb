class CreateCategories < ActiveRecord::Migration
  def up
    create_table :time_off_categories, id: :uuid do |t|
      t.string :name, null: false
      t.boolean :system, null: false, default: false
      t.uuid :account_id, null: false
      t.timestamps null: false
    end
    add_foreign_key :time_off_categories, :accounts, on_delete: :cascade, column: :account_id
    add_index :time_off_categories, :account_id
  end

  def down
    drop_table :time_off_categories
  end
end
