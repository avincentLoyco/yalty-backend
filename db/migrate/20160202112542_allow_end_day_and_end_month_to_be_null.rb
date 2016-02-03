class AllowEndDayAndEndMonthToBeNull < ActiveRecord::Migration
  def change
    change_column :time_off_policies, :end_day, :integer, null: true
    change_column :time_off_policies, :end_month, :integer, null: true
  end
end
