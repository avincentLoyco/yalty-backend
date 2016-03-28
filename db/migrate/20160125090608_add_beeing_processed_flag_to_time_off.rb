class AddBeeingProcessedFlagToTimeOff < ActiveRecord::Migration
  def change
    add_column :time_offs, :beeing_processed, :boolean, default: :false
  end
end
