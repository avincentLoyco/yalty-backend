class RemoveNotNullOnAttrDefintionLabel < ActiveRecord::Migration
  def change
    change_column_null(:employee_attribute_definitions, :label, true)
  end
end
