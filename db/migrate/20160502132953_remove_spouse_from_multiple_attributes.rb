class RemoveSpouseFromMultipleAttributes < ActiveRecord::Migration
  def up
    Employee::AttributeDefinition.where(name: 'spouse')
      .update_all(multiple: false)
    Employee::AttributeVersion.joins(:attribute_definition)
      .where(['employee_attribute_definitions.name = ?', 'spouse'])
      .update_all(order: nil, multiple: false)
  end

  def down
    Employee::AttributeVersion.joins(:attribute_definition)
      .where(['employee_attribute_definitions.name = ?', 'spouse'])
      .update_all(order: 1, multiple: true)
    Employee::AttributeDefinition.where(name: 'spouse')
      .update_all(multiple: true)
  end
end
