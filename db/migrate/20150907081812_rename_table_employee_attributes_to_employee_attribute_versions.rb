class RenameTableEmployeeAttributesToEmployeeAttributeVersions < ActiveRecord::Migration
  def change
    rename_table :employee_attributes, :employee_attribute_versions
  end
end
