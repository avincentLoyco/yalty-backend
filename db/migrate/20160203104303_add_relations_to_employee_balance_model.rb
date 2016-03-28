class AddRelationsToEmployeeBalanceModel < ActiveRecord::Migration
  def change
    add_column :employee_balances, :balance_credit_addition_id, :uuid
    add_index :employee_balances, :balance_credit_addition_id
  end
end
