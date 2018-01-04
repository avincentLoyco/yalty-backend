desc 'Set Time Off Policies created before 2018 (migration) as inactive'
task set_time_off_policies_created_before_2018_as_inactive: :environment do
  TimeOffPolicy
    .where('created_at < ?', Date.new(2018, 1, 1))
    .not_default_counters
    .each do |time_off_policy|
      time_off_policy.update_attribute('active', false)
    end
end
