module Api::V1
  class SettingsRepresenter < BaseRepresenter
    def complete
      {
        company_name:      resource.company_name,
        subdomain:         resource.subdomain,
        available_modules: resource.available_modules.plan_ids,
        default_locale:    resource.default_locale,
        timezone:          resource.timezone
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
