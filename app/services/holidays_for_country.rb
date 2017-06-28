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
    calculate_holiday
  end

  private

  def calculate_holiday
    regions_holidays = {}
    holidays = []
    filtered_holidays.each do |holiday|
      holidays << { date: holiday[:date], code: holiday[:name] }
      next if region.present? || !regions?
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
    if filter.present?
      Holidays.between(Time.zone.now, Time.zone.now + 2.years, country).first(10)
    else
      Holidays.between(Time.zone.now.beginning_of_year, Time.zone.now.end_of_year, country)
    end
  end

  def valid_params?
    (filter.nil? || filter.eql?('upcoming')) && regions? && (region.nil? ||
      Holidays.available_regions.include?(country.to_sym))
  end

  def check_params
    return if valid_params?
    raise(
      CustomError,
      type: 'holiday',
      field: 'country',
      messages: ['Invalid param value'],
      codes: ['country.invalid_param_value']
    )
  end
end
