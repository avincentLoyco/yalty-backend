class AddUuidToWorkingPlaceModel < ActiveRecord::Migration
  def up
    add_column :working_places, :uuid, :uuid, default: 'uuid_generate_v4()'
    execute 'ALTER TABLE working_places DROP id CASCADE'
    rename_column :working_places, :uuid, :id
    change_column :employees, :working_place_id, :uuid, using: 'uuid_generate_v4()'
    execute "ALTER TABLE working_places ADD PRIMARY KEY (id);"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
