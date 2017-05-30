class AddBalanceInHoursToUsers < ActiveRecord::Migration
  def change
    add_column :account_users, :balance_in_hours, :boolean
    change_column_null :account_users, :balance_in_hours, false, false
    change_column_default :account_users, :balance_in_hours, false
  end
end
