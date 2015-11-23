module Api::V1
  class SettingsRepresenter < BaseRepresenter
    def complete
      {
        subdomain:         resource.subdomain,
        company_name:      resource.company_name,
        timezone:          resource.timezone,
        default_locale:    resource.default_locale
      }
        .merge(basic)
        .merge(relationships)
    end

    def public_data
      {
        company_name:      resource.company_name,
        default_locale:    resource.default_locale
      }
    end

    def relationships
      holiday_policy = HolidayPolicyRepresenter.new(resource.holiday_policy).basic
      {
        holiday_policy: holiday_policy
      }
    end

    def subdomain
      {
        subdomain: resource.subdomain
      }
    end
  end
end
