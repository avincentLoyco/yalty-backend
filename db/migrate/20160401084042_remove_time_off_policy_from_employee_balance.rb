class RemoveTimeOffPolicyFromEmployeeBalance < ActiveRecord::Migration
  def change
    remove_column :employee_balances, :time_off_policy_id
  end
end
