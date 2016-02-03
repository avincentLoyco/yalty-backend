class AddPolicyCreditAdditionFlagToEmployeeBalance < ActiveRecord::Migration
  def change
    add_column :employee_balances, :validity_date, :date
    add_column :employee_balances, :policy_credit_removal, :boolean, default: false
  end
end
