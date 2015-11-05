class AddOrderToEmployeeAttributeVersion < ActiveRecord::Migration
  def up
    add_column :employee_attribute_versions, :order, :integer
  end

  def down
    remove_column :employee_attribute_versions, :order
  end
end
