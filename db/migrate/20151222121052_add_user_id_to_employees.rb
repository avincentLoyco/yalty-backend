class AddUserIdToEmployees < ActiveRecord::Migration
  def change
    add_column :employees, :account_user_id, :uuid, index: true, foreign_key: true
  end
end
