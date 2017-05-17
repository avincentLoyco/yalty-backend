desc 'Add standard_day_duration to existing presence policies'
task add_standard_day_duration: :environment do
  PresencePolicy.all.each do |pp|
    next if pp.standard_day_duration.present? || pp.reset || pp.presence_days.empty?

    pp.update!(standard_day_duration: pp.presence_days.map(&:minutes).compact.max)
  end
end
