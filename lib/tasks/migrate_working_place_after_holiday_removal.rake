task migrate_working_place_after_holiday_removal: [:environment] do
  # First update working place that doesn't have coordinate but a holiday policy
  print 'Update working places with their holiday coordinate'
  WorkingPlace.includes(:holiday_policy)
              .where(country: nil).where.not(holiday_policy_id: nil)
              .each do |wp|

    wp.state = wp.holiday_policy.region.upcase
    wp.country = wp.holiday_policy.country.upcase
    wp.save!

    print '.'
  end
  print "\n"

  # Then remove duplicate policies for same country and region
  print 'Remove duplicated holiday policies'
  HolidayPolicy.select(:account_id, :region, :country)
               .group(:account_id, :region, :country)
               .having('count(*) > 1').each do |dup|
    HolidayPolicy.where(account_id: dup.account.id, region: dup.region, country: dup.country)
                 .each_with_index do |hp, index|
      next if index.zero?
      hp.destroy
    end

    print '.'
  end
  print "\n"

  # Then assign a policy for any working place that have valid coordinate
  print 'Ensure all working placess that have valud coordinate have a holiday policy assigned'
  WorkingPlace.where.not(country: nil).each do |wp|
    AssignHolidayPolicy.new(wp).call

    print '.'
  end
  print "\n"

  # Finally destroy orphan holiday policies
  puts 'Destroy holidays policies that doesn\'t have any working place assigned'
  HolidayPolicy.includes(:working_places).where(working_places: { holiday_policy_id: nil })
               .destroy_all
end
