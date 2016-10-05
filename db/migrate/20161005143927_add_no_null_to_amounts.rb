class AddNoNullToAmounts < ActiveRecord::Migration
  def change
    change_column_null :employee_balances, :balance, false
    change_column_null :employee_balances, :manual_amount, false
    change_column_null :employee_balances, :resource_amount, false
  end
end
