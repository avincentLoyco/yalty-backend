class CreateEmployeePresencePolicy < ActiveRecord::Migration
  def change
    create_table :employee_presence_policies, id: :uuid do |t|
      t.uuid :employee_id, null: false
      t.uuid :presence_policy_id, null: false
      t.date :effective_at, null: false
      t.integer :start_day_order, default: 1, null: false
    end

    add_foreign_key :employee_presence_policies,
                    :employees,
                    on_delete: :cascade,
                    column: :employee_id
    add_foreign_key :employee_presence_policies,
                    :presence_policies,
                    on_delete: :cascade,
                    column: :presence_policy_id

    add_index :employee_presence_policies, :employee_id
    add_index :employee_presence_policies, :presence_policy_id
    add_index :employee_presence_policies,
      [:presence_policy_id, :employee_id],
      name: "index_employee_id_presence_policy_id"
    add_index :employee_presence_policies,
      [:employee_id, :presence_policy_id, :effective_at],
      unique: true,
      name: "index_employee_presence_policy_effective_at"
  end
end
