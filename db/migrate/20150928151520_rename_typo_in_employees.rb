class RenameTypoInEmployees < ActiveRecord::Migration
  def change
    rename_column :employees, :holiday_policy, :holiday_policy_id
  end
end
