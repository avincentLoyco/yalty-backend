class AddRelationBetweenEmployeeBalanceAndTimeOffPolicy < ActiveRecord::Migration
  def up
    add_column :employee_balances, :time_off_policy_id, :uuid
    add_foreign_key :employee_balances, :time_off_policies, column: :time_off_policy_id
    add_index :employee_balances, :time_off_policy_id
  end

  def down
    remove_column :employee_balances, :time_off_policy_id
  end
end
