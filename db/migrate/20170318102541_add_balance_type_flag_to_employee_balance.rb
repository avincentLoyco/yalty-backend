class AddBalanceTypeFlagToEmployeeBalance < ActiveRecord::Migration
  def change
    add_column :employee_balances, :balance_type, :string
    Rake::Task['assign_types_to_existing_balances:update'].invoke

    change_column :employee_balances, :balance_type, :string, null: false

    remove_column :employee_balances, :reset_balance
    remove_column :employee_balances, :policy_credit_addition
  end
end
