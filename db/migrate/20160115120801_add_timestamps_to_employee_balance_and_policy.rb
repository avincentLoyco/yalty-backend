class AddTimestampsToEmployeeBalanceAndPolicy < ActiveRecord::Migration
  def change
    add_column(:employee_balances, :created_at, :datetime)
    add_column(:employee_balances, :updated_at, :datetime)
    add_column(:time_off_policies, :created_at, :datetime)
    add_column(:time_off_policies, :updated_at, :datetime)
  end
end
