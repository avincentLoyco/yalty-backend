class AddPolicyCreditAdditionFlagToEmployeeBalance < ActiveRecord::Migration
  def change
    add_column :employee_balances, :policy_credit_addition, :boolean, default: false
    add_column :employee_balances, :policy_credit_removal, :boolean, default: false
  end
end
