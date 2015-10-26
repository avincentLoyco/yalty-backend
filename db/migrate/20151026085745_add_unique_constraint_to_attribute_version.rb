class AddUniqueConstraintToAttributeVersion < ActiveRecord::Migration
  def change
    add_index :employee_attribute_versions,
      [:attribute_definition_id, :employee_id, :employee_event_id],
      unique: true, name: :employee_attribute_versions_uniqueness
  end
end
