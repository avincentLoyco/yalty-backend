class ChangeTimeEntryStartAndTimeTypeToString < ActiveRecord::Migration
  def change
    change_column :time_entries, :start_time, :string, null: false
    change_column :time_entries, :end_time, :string, null: false
  end
end
