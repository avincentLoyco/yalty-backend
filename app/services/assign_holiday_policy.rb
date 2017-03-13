class AssignHolidayPolicy
  include API::V1::Exceptions
  attr_reader :working_place, :holiday_policy_id

  def initialize(working_place)
    @working_place = working_place
  end

  def call
    working_place.update!(holiday_policy: holiday_policy)
  end

  private

  def holiday_policy
    @holiday_policy ||= find_or_create_policy if HolidayPolicy::COUNTRIES.include?(country_code)
  end

  def find_or_create_policy
    return unless country_code.present?

    holiday_policies.find_or_create_by!(region: state_code, country: country_code) do |policy|
      policy.name = state_code ? "#{working_place.country} (#{working_place.state})" : policy.name
    end
  rescue ActiveRecord::RecordInvalid
    nil
  end

  def holiday_policies
    working_place.account.holiday_policies
  end

  def country_code
    working_place.country_code&.downcase
  end

  def state_code
    return unless HolidayPolicy.country_with_regions?(country_code)
    working_place.state_code&.downcase
  end
end
