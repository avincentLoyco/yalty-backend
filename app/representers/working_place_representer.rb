class WorkingPlaceRepresenter < BaseRepresenter
  def complete
    {
      name: resource.name
    }
      .merge(basic)
      .merge(relationships)
  end

  def relationships
    holiday_policy = HolidayPolicyRepresenter.new(resource.holiday_policy).basic
    {
      holiday_policy: holiday_policy
    }
  end
end
