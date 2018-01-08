module Api::V1
  class SettingsRepresenter < BaseRepresenter
    def complete
      {
        company_name:            resource.company_name,
        subdomain:               resource.subdomain,
        yalty_access:            resource.yalty_access,
        available_modules:       resource.available_modules.all,
        default_locale:          resource.default_locale,
        timezone:                resource.timezone,
        default_presence_policy: default_presence_policy
      }
        .merge(basic)
        .merge(company_information_json)
    end

    def public_data
      {
        company_name:      resource.company_name,
        default_locale:    resource.default_locale
      }
    end

    private

    def default_presence_policy
      return if resource.presence_policies.full_time.nil?
      PresencePolicyRepresenter.new(resource.presence_policies.full_time).complete
    end

    def company_information_json
      {
        company_information: {
          company_name: resource.company_information.company_name,
          address_1: resource.company_information.address_1,
          address_2: resource.company_information.address_2,
          city: resource.company_information.city,
          country: resource.company_information.country,
          postalcode: resource.company_information.postalcode,
          region: resource.company_information.region,
          phone: resource.company_information.phone
        }
      }
    end
  end
end
