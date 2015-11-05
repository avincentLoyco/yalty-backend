class CreatePresenceDays < ActiveRecord::Migration
  def up
    create_table :presence_days, id: :uuid do |t|
      t.integer :order
      t.uuid :presence_policy_id, index: true, foreign_key: { on_delete: :cascade }, null: false
      t.decimal :hours
      t.timestamps null: false
    end
  end

  def down
    drop_table :presence_days
  end
end
