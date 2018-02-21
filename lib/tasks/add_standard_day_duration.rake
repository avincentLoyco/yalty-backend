desc "Add standard_day_duration to existing presence policies"
task add_standard_day_duration: :environment do
  PresencePolicy.where(standard_day_duration: nil, reset: false).each do |pp|
    next if pp.presence_days.empty?

    pp.update!(standard_day_duration: pp.presence_days.map(&:minutes).compact.max)
  end
end
