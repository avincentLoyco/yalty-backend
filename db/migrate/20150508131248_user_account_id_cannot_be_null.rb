class UserAccountIdCannotBeNull < ActiveRecord::Migration
  def change
    change_column_null(:users, :account_id, false)
  end
end
