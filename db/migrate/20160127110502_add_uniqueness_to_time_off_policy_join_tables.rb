class AddUniquenessToTimeOffPolicyJoinTables < ActiveRecord::Migration
  def change
    add_index :employee_time_off_policies,
      [:time_off_policy_id, :employee_id],
      unique: true,
      name: "index_employee_id_time_off_policy_id"
    add_index :working_place_time_off_policies,
      [:time_off_policy_id, :working_place_id],
      unique: true,
      name: "index_working_place_id_time_off_policy_id"
  end
end
