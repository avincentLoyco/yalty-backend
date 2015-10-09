module SettingsRules
  include BaseRules

  def patch_rules
    Gate.rules do
      optional :subdomain
      optional :company_name
      optional :timezone
      optional :default_locale
      optional :holiday_policy, allow_nil: true do
        required :id
      end
    end
  end

  def put_rules
    Gate.rules do
      required :subdomain
      required :company_name
      optional :timezone
      optional :default_locale
      optional :holiday_policy, allow_nil: true do
        required :id
      end
    end
  end

end
