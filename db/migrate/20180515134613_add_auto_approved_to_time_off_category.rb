class AddAutoApprovedToTimeOffCategory < ActiveRecord::Migration
  def change
    add_column :time_off_categories, :auto_approved, :boolean
    change_column_default :time_off_categories, :auto_approved, false
    execute("UPDATE time_off_categories SET auto_approved = FALSE")
  end
end
