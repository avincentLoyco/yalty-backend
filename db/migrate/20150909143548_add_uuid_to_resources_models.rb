class AddUuidToResourcesModels < ActiveRecord::Migration
  def up
    add_column :employee_attribute_versions, :uuid, :uuid, default: 'uuid_generate_v4()'
    add_column :employee_attribute_definitions, :uuid, :uuid, default: 'uuid_generate_v4()'
    add_column :employee_events, :uuid, :uuid, default: 'uuid_generate_v4()'

    execute 'ALTER TABLE employees DROP id CASCADE'
    execute 'ALTER TABLE employee_attribute_versions DROP id CASCADE'
    execute 'ALTER TABLE employee_attribute_definitions DROP id CASCADE'
    execute 'ALTER TABLE employee_events DROP id CASCADE'

    rename_column :employees, :uuid, :id
    rename_column :employee_attribute_versions, :uuid, :id
    rename_column :employee_attribute_definitions, :uuid, :id
    rename_column :employee_events, :uuid, :id

    change_column :employee_attribute_versions, :employee_id, :uuid, using: 'uuid_generate_v4()'
    change_column :employee_attribute_versions, :attribute_definition_id, :uuid, using: 'uuid_generate_v4()'
    change_column :employee_attribute_versions, :employee_event_id, :uuid, using: 'uuid_generate_v4()'
    change_column :employee_events, :employee_id, :uuid, using: 'uuid_generate_v4()'

    execute "ALTER TABLE employees ADD PRIMARY KEY (id);"
    execute "ALTER TABLE employee_attribute_versions ADD PRIMARY KEY (id);"
    execute "ALTER TABLE employee_attribute_definitions ADD PRIMARY KEY (id);"
    execute "ALTER TABLE employee_events ADD PRIMARY KEY (id);"

    create_view :employee_attributes, version: 2
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
