class AddLongTokenAllowedFieldToEmployeeAttributeVersions < ActiveRecord::Migration
  def change
    add_column :employee_attribute_definitions,
      :long_token_allowed,
      :boolean
    change_column_default :employee_attribute_definitions, :long_token_allowed, false
    execute('UPDATE employee_attribute_definitions SET long_token_allowed = false')
    change_column_null :employee_attribute_definitions, :long_token_allowed, false
  end
end
