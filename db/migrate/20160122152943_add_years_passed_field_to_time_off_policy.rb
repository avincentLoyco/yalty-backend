class AddYearsPassedFieldToTimeOffPolicy < ActiveRecord::Migration
  def change
    add_column :time_off_policies, :years_passed, :integer, null: false, default: 0
  end
end
