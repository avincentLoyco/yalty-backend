class AddDurationFieldToTimeEntry < ActiveRecord::Migration
  def change
    add_column :time_entries, :duration, :integer, null: false, default: 0
  end
end
