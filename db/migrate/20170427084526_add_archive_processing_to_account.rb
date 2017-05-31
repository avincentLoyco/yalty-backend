class AddArchiveProcessingToAccount < ActiveRecord::Migration
  def change
    add_column :accounts, :archive_processing, :boolean, default: false
  end
end
