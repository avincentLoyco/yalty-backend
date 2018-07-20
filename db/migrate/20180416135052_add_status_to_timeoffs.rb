class AddStatusToTimeoffs < ActiveRecord::Migration
  def change
    add_column :time_offs, :approval_status, :integer
    change_column_default :time_offs, :approval_status, 0
    execute("UPDATE time_offs SET approval_status = 0")
    add_index :time_offs, :approval_status
  end
end
