class CreateGenericFile < ActiveRecord::Migration
  def change
    rename_table :employee_files, :generic_files
    add_column :generic_files, :fileable_id, :uuid
    add_column :generic_files, :fileable_type, :string
    add_index :generic_files, [:fileable_id, :fileable_type]
    add_column :generic_files, :sha_sums, :json
  end
end
