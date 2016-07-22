class ChangeOrderForDuplicatedEmployeeAttributesVersions < ActiveRecord::Migration
  def change
    duplicated_records =
      ActiveRecord::Base.connection.select_all(
        "
          SELECT employee_attribute_versions.attribute_definition_id,
            employee_attribute_versions.employee_id, employee_attribute_versions.order
          FROM employee_attribute_versions
          WHERE employee_attribute_versions.order IS NOT NULL
          GROUP BY employee_attribute_versions.order, employee_attribute_versions.employee_id,
            employee_attribute_versions.attribute_definition_id
          HAVING count(*) > 1
	    ").to_ary

    duplicated_records.each do |duplicated|
      versions_to_update =
        Employee::AttributeVersion.where(
          attribute_definition_id: duplicated['attribute_definition_id'],
          employee_id: duplicated['employee_id']
        )
        .order(:created_at)

      versions_to_update.each_with_index do |version, index|
        version.update!(order: index + 1 + versions_to_update.size)
      end
      versions_to_update.each_with_index do |version, index|
        version.update!(order: index + 1)
      end
    end

    add_index :employee_attribute_versions,
      [:employee_id, :attribute_definition_id, :order],
      unique: true,
      name: "index_employee_id_working_place_id_order"
  end
end
