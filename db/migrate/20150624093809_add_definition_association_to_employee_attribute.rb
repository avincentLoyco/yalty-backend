class AddDefinitionAssociationToEmployeeAttribute < ActiveRecord::Migration
  def change
    remove_column :employee_attributes, :name
    add_column :employee_attributes, :attribute_definition_id, :integer
    add_index :employee_attributes, :attribute_definition_id
    add_foreign_key :employee_attributes, :employee_attribute_definitions,
      on_delete: :cascade,
      column: :attribute_definition_id
  end
end
