class RenameUsersToAccountUsers < ActiveRecord::Migration
  def change
    rename_table 'users', 'account_users'
  end
end
