class AddEffectiveAtToTimeOffPolicies < ActiveRecord::Migration

  class EmployeeTimeOffPolicy < ActiveRecord::Base
    belongs_to :time_off_policy
  end

  class WorkingPlaceTimeOffPolicy < ActiveRecord::Base
    belongs_to :time_off_policy
  end

  def change
    add_column :employee_time_off_policies, :effective_at, :datetime
    add_column :working_place_time_off_policies, :effective_at, :datetime

    EmployeeTimeOffPolicy.all.each do |etop|
      etop.update_attribute(:effective_at, etop.time_off_policy.created_at)
    end

    WorkingPlaceTimeOffPolicy.all.each do |wptop|
      wptop.update_attribute(:effective_at, wptop.time_off_policy.created_at)
    end

    remove_index :employee_time_off_policies, name: "index_employee_id_time_off_policy_id"
    remove_index :working_place_time_off_policies, name: "index_working_place_id_time_off_policy_id"

    add_index :employee_time_off_policies,
      [:time_off_policy_id, :employee_id],
      name: "index_employee_id_time_off_policy_id"
    add_index :employee_time_off_policies,
      [:employee_id, :time_off_policy_id, :effective_at],
      unique: true,
      name: "index_employee_time_off_policy_effective_at"

    add_index :working_place_time_off_policies,
      [:time_off_policy_id, :working_place_id],
      name: "index_working_place_id_time_off_policy_id"
    add_index :working_place_time_off_policies,
      [:working_place_id, :time_off_policy_id, :effective_at],
      unique: true,
      name: "index_working_place_time_off_policy_effective_at"

    change_column_null :employee_time_off_policies, :effective_at, true
    change_column_null :working_place_time_off_policies, :effective_at, true
  end
end
