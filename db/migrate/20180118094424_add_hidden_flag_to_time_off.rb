class AddHiddenFlagToTimeOff < ActiveRecord::Migration
  def change
    add_column :time_offs, :hidden, :bool
    change_column_default :time_offs, :hidden, false
  end
end
