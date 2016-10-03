class AddManualAmountFieldToEmployeeBalanceRenameAmountToResourceAmount < ActiveRecord::Migration
  def change
    add_column :employee_balances, :manual_amount, :integer, default: 0, allow_nil: false
    rename_column :employee_balances, :amount, :resource_amount
    change_column :employee_balances, :resource_amount, :integer, allow_nil: false
  end
end
