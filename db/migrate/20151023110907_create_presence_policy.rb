class CreatePresencePolicy < ActiveRecord::Migration
  def up
    create_table :presence_policies, id: :uuid do |t|
      t.references :account, index: true, foreign_key: { on_delete: :cascade }, null: false
      t.string :name
      t.timestamps null: false
    end
  end

  def down
    drop_table :presence_policies
  end
end
