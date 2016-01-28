class AddEffectiveAtFieldToEmployeeBalance < ActiveRecord::Migration
  def change
    add_column :employee_balances, :effective_at, :timestamp, null: false, default: Time.now

    execute <<-SQL
      UPDATE employee_balances
      SET effective_at = (employee_balances.created_at)
    SQL
  end
end
