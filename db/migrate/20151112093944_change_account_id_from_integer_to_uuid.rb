class ChangeAccountIdFromIntegerToUuid < ActiveRecord::Migration
  def up
    execute 'DELETE from accounts;'

    add_column :accounts, :uuid, :uuid, default: "uuid_generate_v4()", null: false

    execute 'ALTER TABLE accounts DROP id CASCADE'

    rename_column :accounts, :uuid, :id

    change_column :account_users, :account_id, :uuid, using: 'uuid_generate_v4()'
    change_column :employee_attribute_definitions, :account_id, :uuid, using: 'uuid_generate_v4()'
    change_column :employees, :account_id, :uuid, using: 'uuid_generate_v4()'
    change_column :holiday_policies, :account_id, :uuid, using: 'uuid_generate_v4()'
    change_column :presence_policies, :account_id, :uuid, using: 'uuid_generate_v4()'
    change_column :working_places, :account_id, :uuid, using: 'uuid_generate_v4()'

    execute "ALTER TABLE accounts ADD PRIMARY KEY (id);"

    add_foreign_key :presence_policies, :accounts, on_delete: :cascade
    add_foreign_key :account_users, :accounts, on_delete: :cascade
    add_foreign_key :holiday_policies, :accounts, on_delete: :cascade
    add_foreign_key :working_places, :accounts, on_delete: :cascade
    add_foreign_key :employees, :accounts, on_delete: :cascade
    add_foreign_key :employee_attribute_definitions, :accounts, on_delete: :cascade
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
