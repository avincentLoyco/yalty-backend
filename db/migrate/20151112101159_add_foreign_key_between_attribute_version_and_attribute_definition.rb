class AddForeignKeyBetweenAttributeVersionAndAttributeDefinition < ActiveRecord::Migration
  def up
    add_foreign_key :employee_attribute_versions, :employee_attribute_definitions, column: :attribute_definition_id
  end

  def down
    remove_foreign_key :employee_attribute_versions, :attribute_definitions
  end
end
