class AssignHolidayPolicy
  include API::V1::Exceptions
  attr_reader :working_place, :holiday_policy_id

  def initialize(working_place, holiday_policy_id)
    @working_place = working_place
    @holiday_policy_id = holiday_policy_id
  end

  def call
    working_place.update!(holiday_policy: holiday_policy)
  end

  private

  def holiday_policy
    @holiday_policy ||= begin
      if holiday_policy_id.present?
        holiday_policies.find(holiday_policy_id)
      elsif HolidayPolicy::COUNTRIES.include?(country_code)
        find_or_create_policy
      end
    end
  end

  def find_or_create_policy
    holiday_policies.find_or_create_by!(region: state_code, country: country_code) do |policy|
      if state_code
        policy.name = "#{working_place.country} (#{working_place.state})"
      else
        policy.name = working_place.country
      end
    end
  end

  def holiday_policies
    Account.current.holiday_policies
  end

  def country_code
    working_place.country_code.downcase
  end

  def state_code
    return unless HolidayPolicy::COUNTRIES_WITH_REGIONS.include?(country_code)
    working_place.state_code.downcase
  end
end
