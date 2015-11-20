class AddResetPasswordTokenColumnToAccountUser < ActiveRecord::Migration
  def up
    add_column :account_users, :reset_password_token, :string, allow_nil: :true
  end

  def down
    remove_column :account_users, :reset_password_token
  end
end
