class ChangeDoorkeeperOwnerIdFromIntegerToUuid < ActiveRecord::Migration
  def up
    execute 'DELETE from oauth_access_grants;'
    execute 'DELETE from oauth_access_tokens'

    change_column :oauth_access_grants, :resource_owner_id, :uuid, using: 'uuid_generate_v4()'
    change_column :oauth_access_tokens, :resource_owner_id, :uuid, using: 'uuid_generate_v4()'

    add_foreign_key :oauth_access_grants, :account_users, column: :resource_owner_id, on_delete: :cascade
    add_foreign_key :oauth_access_tokens, :account_users, column: :resource_owner_id, on_delete: :cascade
  end

  def down
    execute 'DELETE from oauth_access_grants'
    execute 'DELETE from oauth_access_tokens'

    change_column :oauth_access_grants, :resource_owner_id, :integer, using: '0'
    change_column :oauth_access_tokens, :resource_owner_id, :integer, using: '0'

    remove_foreign_key :oauth_access_grants
    remove_foreign_key :oauth_access_tokens
  end
end
