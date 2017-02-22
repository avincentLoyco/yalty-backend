class AddLongTokenAllowedFieldToEmployeeAttributeVersions < ActiveRecord::Migration
  def change
    add_column :employee_attribute_definitions,
      :long_token_allowed,
      :boolean,
      default: false,
      null: false
  end
end
