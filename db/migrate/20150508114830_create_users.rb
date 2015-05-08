class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.belongs_to :account, index: true, foreign_key: { on_delete: :cascade }

      t.timestamps null: false
    end
    add_index :users, [:email, :account_id], unique: true
  end
end
