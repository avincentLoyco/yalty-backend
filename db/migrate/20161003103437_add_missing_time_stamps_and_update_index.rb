class AddMissingTimeStampsAndUpdateIndex < ActiveRecord::Migration
  def change
    EmployeeTimeOffPolicy.all.each do |etop|
      unless etop.valid?
        duplicated =
          etop
          .employee
          .employee_time_off_policies
          .where(time_off_category: etop.time_off_category, effective_at: etop.effective_at)
          
        if duplicated.size > 1
          older = duplicated.map(&:time_off_policy).sort_by { |policy| policy[:created_at] }.last
          duplicated.where(time_off_policy: older).first.destroy!
        end
      end
    end

    remove_index :employee_time_off_policies, name: 'index_employee_time_off_policy_effective_at'
    add_index :employee_time_off_policies,
      [:employee_id, :time_off_category_id, :effective_at],
      unique: true,
      name: 'index_employee_time_off_category_effective_at'
    add_column :employee_presence_policies, :created_at, :datetime
    add_column :employee_presence_policies, :updated_at, :datetime
    EmployeePresencePolicy.update_all(created_at: Time.zone.now, updated_at: Time.zone.now)
    add_column :employee_time_off_policies, :created_at, :datetime
    add_column :employee_time_off_policies, :updated_at, :datetime
    EmployeeTimeOffPolicy.update_all(created_at: Time.zone.now, updated_at: Time.zone.now)
    add_column :employee_working_places, :created_at, :datetime
    add_column :employee_working_places, :updated_at, :datetime
    EmployeeWorkingPlace.update_all(created_at: Time.zone.now, updated_at: Time.zone.now)
  end
end
