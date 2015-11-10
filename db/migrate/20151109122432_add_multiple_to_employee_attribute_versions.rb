class AddMultipleToEmployeeAttributeVersions < ActiveRecord::Migration
  def change
    add_column :employee_attribute_versions, :multiple, :boolean, default: false, null: false
  end
end
