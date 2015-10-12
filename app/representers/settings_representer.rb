class SettingsRepresenter < BaseRepresenter

  def complete
    {
      subdomain:         resource.subdomain,
      company_name:      resource.company_name,
      timezone:          resource.timezone,
      default_locale:    resource.default_locale,
    }
    .merge(basic)
    .merge(relationships)
  end

  def relationships
    if  resource.holiday_policy.present?
      holiday_policy = HolidayPolicyRepresenter.new( resource.holiday_policy).basic
    end
    {
      holiday_policy: holiday_policy || {},
    }
  end
end
