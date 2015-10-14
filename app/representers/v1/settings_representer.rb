module V1
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
      holiday_policy = HolidayPolicyRepresenter.new( resource.holiday_policy).basic
      {
        holiday_policy: holiday_policy
      }
    end
  end
end
