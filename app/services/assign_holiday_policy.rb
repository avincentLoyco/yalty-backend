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
    return holiday_policies.find(holiday_policy_id) if holiday_policy_id.present?
    find_or_create_policy if HolidayPolicy::AUTHORIZED_COUNTRIES.include?(country_code)
  end

  def find_or_create_policy
    holiday_policies
      .where(region: working_place.state_code).find_or_create_by!(country: country_code) do |policy|
        policy.name = working_place.state_code.present? ? working_place.state_code : country_code
        policy.region = working_place.state_code if working_place.state_code.present?
      end
  end

  def holiday_policies
    Account.current.holiday_policies
  end

  def country_code
    return nil if working_place.country.nil?
    working_place.country_code
  end
end
