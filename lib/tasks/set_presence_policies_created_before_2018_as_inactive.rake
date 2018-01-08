desc 'Set Presence Policies created before 2018 (migration) as inactive'
task set_presence_policies_created_before_2018_as_inactive: :environment do
  PresencePolicy
    .where('created_at < ?', Date.new(2018, 1, 1))
    .each do |presence_policy|
      presence_policy.update_attribute('active', false)
    end
end
