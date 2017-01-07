class HolidaysForCountry
  include API::V1::Exceptions
  attr_reader :country_code, :region, :filter

  def initialize(country, region = nil, filter = nil)
    @country_code = country
    @region = region
    @filter = filter
  end

  def call
    check_params
    calculate_holiday(filtered_holidays)
  end

  private

  def calculate_holiday(holiday_list)
    regions_holidays = {}
    holidays = []
    holiday_list.each do |holiday|
      holidays << { date: holiday[:date], code: holiday[:name] }
      next if region.present? || regions? == false
      regions_holidays = assign_regions_holidays(regions_holidays, holiday)
    end
    { holidays: holidays, regions: regions_holidays.values }
  end

  def assign_regions_holidays(regions_holidays, holiday)
    holiday[:regions].each do |region_code|
      next unless region_code.to_s.starts_with?(country_code)
      regions_holidays[region_code] ||= { code: region_code, holidays: [] }
      regions_holidays[region_code][:holidays] << holiday[:name]
    end
    regions_holidays
  end

  def country
    country = regions? ? "#{country_code}_" : country_code
    country += region if region.present?
    country
  end

  def regions?
    !HolidayPolicy::COUNTRIES_WITHOUT_REGIONS.include?(country_code)
  end

  def filtered_holidays
    filter.present? ? incoming_holidays : year_holidays
  end

  def invalid_region?
    regions? == false && region.present?
  end

  def region_exists?
    region.nil? || Holidays.available_regions.include?(country.to_sym)
  end

  def valid_filter?
    filter.nil? || filter.eql?('upcoming')
  end

  def incoming_holidays
    Holidays.between(Time.zone.now, Time.zone.now + 2.years, country).first(10)
  end

  def year_holidays
    Holidays.between(Time.zone.now.beginning_of_year, Time.zone.now.end_of_year, country)
  end

  def check_params
    return if !invalid_region? && region_exists? && valid_filter?
    raise InvalidParamTypeError.new(country, 'Invalid param value')
  end
end
