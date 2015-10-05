module API
  module V1
    class SettingResource < JSONAPI::Resource
      model_name 'Account'
      attributes :subdomain, :company_name, :timezone, :default_locale, :holiday_policy_id
      key_type :integer
    end
  end
end
