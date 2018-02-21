desc "Destroy duplicate time off policies (of balancer type and with the same amount)"
task destroy_duplicate_time_off_policies: :environment do
  Account.all.each do |account|
    grouped_tops = account.time_off_policies.active_balancers.group_by(&:amount)
    grouped_tops.each do |time_off_policy|
      time_off_policies = time_off_policy.second
      unique_time_off_policy = time_off_policies.first
      time_off_policies = time_off_policies.to_a - [unique_time_off_policy]
      ActiveRecord::Base.transaction do
        time_off_policies.each do |duplicated_top|
          duplicated_top.employee_time_off_policies.each do |etop|
            etop.update(time_off_policy_id: unique_time_off_policy.id)
          end
        end
        time_off_policies.each(&:destroy!)
      end
    end
  end
end
