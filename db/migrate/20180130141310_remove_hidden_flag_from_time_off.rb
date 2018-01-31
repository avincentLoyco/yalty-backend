class RemoveHiddenFlagFromTimeOff < ActiveRecord::Migration
  def change
    remove_column :time_offs, :hidden
  end
end
