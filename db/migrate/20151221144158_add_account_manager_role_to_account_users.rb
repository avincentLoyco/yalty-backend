class AddAccountManagerRoleToAccountUsers < ActiveRecord::Migration
  def change
    add_column :account_users, :account_manager, :boolean, default: false
  end
end
