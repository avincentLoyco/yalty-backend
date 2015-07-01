class RemoveTypeToEmployeeAttributes < ActiveRecord::Migration
  def change
    remove_column :employee_attributes, :type
  end
end
