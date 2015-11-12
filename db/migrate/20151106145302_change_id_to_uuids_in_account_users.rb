class ChangeIdToUuidsInAccountUsers < ActiveRecord::Migration
  def up
    add_column :account_users, :uuid, :uuid, default: "uuid_generate_v4()", null: false
    execute 'ALTER TABLE account_users DROP id CASCADE'
    rename_column :account_users, :uuid, :id
    execute "ALTER TABLE account_users ADD PRIMARY KEY (id);"
  end

  def down
    execute "ALTER TABLE account_users DROP CONSTRAINT account_users_pkey;"
    rename_column :account_users, :id, :uuid
    add_column :account_users, :id, :primary_key
    remove_column :account_users, :uuid
  end
end
