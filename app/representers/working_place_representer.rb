class WorkingPlaceRepresenter < BaseRepresenter
  def complete
    {
      name: resource.name
    }
      .merge(basic)
      .merge(relationships)
  end

  def relationships
    if resource.holiday_policy.present?
      holiday_policy = HolidayPolicyRepresenter.new(resource.holiday_policy).basic
    end
    {
      holiday_policy: holiday_policy || {}
    }
  end
end
