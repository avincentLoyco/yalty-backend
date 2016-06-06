class ChangeEmployeeWorkingPlaceEffectiveAtColumnTypeToDate < ActiveRecord::Migration
  def change
    change_column :employee_working_places, :effective_at, :date
  end
end
