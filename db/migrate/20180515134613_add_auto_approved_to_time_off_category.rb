class AddAutoApprovedToTimeOffCategory < ActiveRecord::Migration
  def change
    add_column :time_off_categories, :auto_approved, :boolean, default: false
  end
end
