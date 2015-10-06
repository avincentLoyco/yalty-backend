class WorkingPlaceRepresenter < BaseRepresenter
  def initialize(working_place)
    @resource = working_place
  end

  def complete
    {
      name: resource.name
    }.merge(basic)
  end

  def relationships
    {
      holiday_policy: HolidayPolicyRepresenter.new(settings.holiday_policy).basic
    }
  end

  private

  attr_reader :resource
end
