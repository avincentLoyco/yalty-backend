class AddStatusToTimeoffs < ActiveRecord::Migration
  def change
    add_column :time_offs, :approval_status, :integer, default: 0
    add_index :time_offs, :approval_status
  end
end
