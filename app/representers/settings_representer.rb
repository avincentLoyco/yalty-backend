class SettingsRepresenter
  attr_accessor :settings

  def initialize(settings)
    @settings = settings
  end

  def basic
    {
      type: 'settings',
    }
  end

  def complete
    {
      subdomain:        settings.subdomain,
      company_name:     settings.company_name,
      timezone:         settings.timezone,
      default_locale:   settings.default_locale,
    }.merge(basic).merge(relationships)
  end

  def relationships
    {
      holiday_policy: HolidayPolicyRepresenter.new(settings.holiday_policy).basic,
    }
  end
end
