class AddArchiveProcessingToAccount < ActiveRecord::Migration
  def change
    add_column :accounts, :archive_processing, :boolean
    change_column_null :accounts, :archive_processing, false, false
    change_column_default :accounts, :archive_processing, false
  end
end
