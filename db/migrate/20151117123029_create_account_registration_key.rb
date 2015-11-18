class CreateAccountRegistrationKey < ActiveRecord::Migration
  def up
    create_table :account_registration_keys, id: :uuid do |t|
      t.string :token
      t.string :account_id, index: true
      t.timestamps null: false
    end
  end

  def down
    drop_table :account_registration_keys
  end
end
