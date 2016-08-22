class AddEmployeeTimeOffPolicyAssociationToEmployeeBalance < ActiveRecord::Migration
  def change
    add_column :employee_balances, :employee_time_off_policy_id, :uuid

    add_foreign_key :employee_balances,
                    :employee_time_off_policies,
                    column: :employee_time_off_policy_id
    add_index :employee_balances, :employee_time_off_policy_id
  end
end
