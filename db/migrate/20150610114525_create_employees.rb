class CreateEmployees < ActiveRecord::Migration
  def change
    create_table :employees do |t|
      t.uuid :uuid, default: 'uuid_generate_v4()'
      t.references :account, index: true, foreign_key: { on_delete: :cascade }

      t.timestamps null: false
    end
    add_index :employees, [:uuid, :account_id], unique: true
  end
end
