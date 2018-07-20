class AddManagerToEmployees < ActiveRecord::Migration
  def change
    add_reference :employees, :manager, index: true, type: :uuid
    add_foreign_key :employees, :account_users, column: :manager_id, on_delete: :nullify
  end
end
