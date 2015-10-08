class HolidayPolicyRepresenter < BaseRepresenter
  def initialize(holiday_policy)
    @resource = holiday_policy
  end

  def complete
    {
      name: resource.name,
      country: resource.country,
      region: resource.region
    }
    .merge(basic)
  end

  private

  attr_reader :resource

end
