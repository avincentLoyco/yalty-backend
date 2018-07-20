class CreateNotifications < ActiveRecord::Migration
  def change
    create_table :notifications, id: :uuid  do |t|
      t.boolean :seen, default: false, null: false
      t.references :user, index: true, type: :uuid, null: false
      t.uuid :resource_id
      t.string :resource_type
      t.string :notification_type

      t.timestamps null: false
    end
    add_foreign_key :notifications, :account_users, column: :user_id, on_delete: :cascade
  end
end
