class HolidayPolicy < ActiveRecord::Base
  belongs_to :account
  has_many :custom_holidays,
    class_name: 'Holiday'
  has_many :working_places
  has_many :employees
  has_one :assigned_account,
    class_name: 'Account',
    foreign_key: :holiday_policy_id,
    inverse_of: :holiday_policy

  validates :name, :account_id, presence: true
  validates :country, presence: true, inclusion: { in: :countries, allow_nil: true },
                      if: :country_or_region_present?

  validates :region, presence: true, inclusion: { in: :regions, allow_nil: true },
                     if: :region_required?

  before_save :unset_region, unless: :region_required?
  before_validation :downcase, if: :local?

  COUNTRIES_WITHOUT_REGIONS = ['ar', 'at', 'be', 'br', 'cl', 'cr', 'cz', 'dk', 'el', 'fr',
                               'je', 'gg', 'im', 'hr', 'hu', 'ie', 'is', 'it', 'li', 'lt',
                               'nl', 'no', 'pl', 'pt', 'ro', 'sk', 'si', 'fi', 'jp', 'ma',
                               'ph', 'se', 'sg', 've', 'vi', 'za']

  def holidays
    if country.present? || region.present?
      custom_holidays + country_holidays
    else
      custom_holidays
    end
  end

  private

  def country_holidays
    Holidays.between(Time.now.beginning_of_year, Time.now.end_of_year, country_with_region).map do |holiday|
      { date: holiday[:date], name: 'Holiday' }
    end
  end

  def country_with_region
    if region.present?
      "#{country}_#{region}".to_sym
    else
      country.to_sym
    end
  end

  def country_or_region_present?
    country.present? || region.present?
  end

  def unset_region
    self[:region] = nil
  end

  def local?
    country || region
  end

  def region_required?
    valid_country? && COUNTRIES_WITHOUT_REGIONS.exclude?(country)
  end

  def valid_country?
    country.present? && countries.include?(country)
  end

  def downcase
    self[:country] = country.try(:downcase)
    self[:region] = region.try(:downcase)
  end

  def countries
    ISO3166::Country.translations.keys.map(&:downcase)
  end

  def regions
    ISO3166::Country.new(country).states.keys.map(&:downcase)
  end
end
