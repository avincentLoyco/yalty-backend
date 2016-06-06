class RemoveYearsPassedFieldFromTimeOffPolicy < ActiveRecord::Migration
  def change
    remove_column :time_off_policies, :years_passed
  end
end
