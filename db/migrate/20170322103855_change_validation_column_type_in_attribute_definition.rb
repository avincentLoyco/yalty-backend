class ChangeValidationColumnTypeInAttributeDefinition < ActiveRecord::Migration
  def change
    rename_column :employee_attribute_definitions, :validation, :old_validation
    add_column :employee_attribute_definitions, :validation, :json
    execute <<-SQL
      UPDATE employee_attribute_definitions SET validation = CAST(old_validation AS json)
    SQL
    remove_column :employee_attribute_definitions, :old_validation
  end
end
