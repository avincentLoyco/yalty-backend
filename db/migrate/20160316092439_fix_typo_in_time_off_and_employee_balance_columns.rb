class FixTypoInTimeOffAndEmployeeBalanceColumns < ActiveRecord::Migration
  def change
    rename_column :employee_balances, :beeing_processed, :being_processed
    rename_column :time_offs, :beeing_processed, :being_processed
  end
end
