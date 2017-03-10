class HolidayPolicy < ActiveRecord::Base
  belongs_to :account
  has_many :working_places
  has_many :employees

  validates :name, :account_id, presence: true
  validates :country, presence: true, inclusion: { in: :countries, allow_nil: true }
  validates :region, presence: true, inclusion: { in: :regions, allow_nil: true },
                     if: :region_required?

  before_validation :downcase_attributes
  before_validation :unset_region, unless: :region_required?

  COUNTRIES_WITH_REGIONS = %w(ch).freeze
  COUNTRIES_WITHOUT_REGIONS = %w().freeze
  COUNTRIES = (COUNTRIES_WITH_REGIONS + COUNTRIES_WITHOUT_REGIONS).freeze

  HolidayStruct = Struct.new(:date, :name)

  def self.country_with_regions?(country)
    return false unless country.present?
    return true if COUNTRIES_WITH_REGIONS.include?(country.downcase)
    COUNTRIES_WITH_REGIONS.include?(
      ISO3166::Country.find_country_by_translated_names(country)&.alpha2&.downcase
    )
  end

  def holidays
    country_holidays if country.present?
  end

  def holidays_in_period(start_date, end_date)
    country_holidays(start_date, end_date) if country.present?
  end

  private

  def country_holidays(from = nil, to = nil)
    from ||= Time.zone.now.beginning_of_year
    to ||= Time.zone.now.end_of_year
    Holidays.between(from, to, country_with_region).map do |holiday|
      HolidayStruct.new(holiday[:date], holiday[:name])
    end
  end

  def country_with_region
    if region.present?
      "#{country}_#{region}".to_sym
    else
      country.to_sym
    end
  end

  def unset_region
    self.region = nil
  end

  def region_required?
    valid_country? && COUNTRIES_WITH_REGIONS.include?(country)
  end

  def valid_country?
    country.present? && countries.include?(country)
  end

  def downcase_attributes
    self.country = country&.downcase
    self.region = region&.downcase
  end

  def countries
    ISO3166::Country.translations.keys.map(&:downcase)
  end

  def regions
    ISO3166::Country.new(country).states.keys.map(&:downcase)
  end
end
