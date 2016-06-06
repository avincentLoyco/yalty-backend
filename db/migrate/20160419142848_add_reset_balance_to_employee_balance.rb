class AddResetBalanceToEmployeeBalance < ActiveRecord::Migration
  def up
    add_column :employee_balances, :reset_balance, :boolean, default: false
  end

  def down
    remove_column :employee_balances, :reset_balance
  end
end
