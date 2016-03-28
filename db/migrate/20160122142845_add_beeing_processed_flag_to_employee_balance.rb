class AddBeeingProcessedFlagToEmployeeBalance < ActiveRecord::Migration
  def change
    add_column :employee_balances, :beeing_processed, :boolean, default: :false
  end
end
