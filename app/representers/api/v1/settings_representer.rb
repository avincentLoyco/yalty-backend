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
    end

    def public_data
      {
        company_name:      resource.company_name,
        default_locale:    resource.default_locale
      }
    end
  end
end
