desc 'Set Time Off Policies created before 2018 (migration) as inactive'
task set_time_off_policies_created_before_2018_as_inactive: :environment do
  TimeOffPolicy.not_default_counters.each do |time_off_policy|
    next unless time_off_policy.created_at < Date.new(2018, 1, 1)
    time_off_policy.update_attribute('active', false)
  end
end
