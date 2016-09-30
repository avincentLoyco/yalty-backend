class RemoveEmployeeTimeOffPolicyRelationFromEmployeeBalance < ActiveRecord::Migration
  def change
    remove_column :employee_balances, :employee_time_off_policy_id
  end
end
