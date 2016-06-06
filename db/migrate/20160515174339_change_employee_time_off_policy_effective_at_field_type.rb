class ChangeEmployeeTimeOffPolicyEffectiveAtFieldType < ActiveRecord::Migration
  def change
    change_column :employee_time_off_policies, :effective_at, :date, null: false
  end
end
