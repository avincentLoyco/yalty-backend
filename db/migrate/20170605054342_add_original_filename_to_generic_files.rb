class AddOriginalFilenameToGenericFiles < ActiveRecord::Migration
  def change
    add_column :generic_files, :original_filename, :string
  end
end
