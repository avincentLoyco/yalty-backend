class UsePartialIndexUniquenessForAttributeVersions < ActiveRecord::Migration
  def change
    remove_index :employee_attribute_versions, name: :employee_attribute_versions_uniqueness
    add_index :employee_attribute_versions,
      [:attribute_definition_id, :employee_id, :employee_event_id],
      unique: true,
      where: "multiple = false",
      name: :employee_attribute_versions_uniqueness_partial
  end
end
