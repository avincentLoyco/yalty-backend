class AddMultipleFlagToAttributeDefinition < ActiveRecord::Migration
  def up
    add_column :employee_attribute_definitions, :multiple, :boolean, default: false, null: false
  end

  def down
    remove_column :employee_attribute_definitions, :multiple
  end
end
