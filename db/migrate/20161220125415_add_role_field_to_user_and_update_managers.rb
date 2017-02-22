class AddRoleFieldToUserAndUpdateManagers < ActiveRecord::Migration
  def change
    add_column :account_users, :role, :string, default: 'user', null: false
    Account::User.where(account_manager: true).update_all(role: 'account_administrator')
    remove_column :account_users, :account_manager, :boolean
    execute("""
      UPDATE account_users users1
      SET role = 'account_owner'
      WHERE users1.created_at = (
        SELECT MIN(created_at) FROM account_users users2
        WHERE role = 'account_administrator'
        AND users2.account_id = users1.account_id)
    """)
  end
end
