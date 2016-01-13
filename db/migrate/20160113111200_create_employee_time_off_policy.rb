class CreateEmployeeTimeOffPolicy < ActiveRecord::Migration
  def change
    create_table :employee_time_off_policies, id: :uuid do |t|
      t.uuid :employee_id, null: false
      t.uuid :time_off_policy_id, null: false
    end
    add_foreign_key :employee_time_off_policies,
                    :employees,
                    on_delete: :cascade,
                    column: :employee_id
    add_foreign_key :employee_time_off_policies,
                    :time_off_policies,
                    on_delete: :cascade,
                    column: :time_off_policy_id
    add_index :employee_time_off_policies, :employee_id
    add_index :employee_time_off_policies, :time_off_policy_id
  end
end
