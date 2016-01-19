class CreateTimeOffPolicy < ActiveRecord::Migration
  def up
    create_table :time_off_policies, id: :uuid do |t|
      t.string :start_time, null: false
      t.string :end_time, null: false
      t.integer :amount, null: false, default: 0
      t.integer :years_to_effect, null: false, default: 0
      t.string :policy_type, null: false
      t.uuid :time_off_category_id, null: false
    end
    add_foreign_key :time_off_policies, :time_off_categories, on_delete: :cascade, column: :time_off_category_id
    add_index :time_off_policies, :time_off_category_id
  end

  def down
    drop_table :time_off_policies
  end
end
