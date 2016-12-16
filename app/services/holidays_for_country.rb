class HolidaysForCountry
  include API::V1::Exceptions
  attr_reader :beginning_of_year, :end_of_year, :country_code, :params, :has_regions
  attr_accessor :country

  def initialize(country, has_regions, params = {})
    @country = has_regions ? "#{country}_" : country
    @country_code = country
    @has_regions = has_regions
    @params = params
    @beginning_of_year = Time.zone.now.beginning_of_year
    @end_of_year = Time.zone.now.end_of_year
  end

  def call
    @country += region if region.present?
    check_params
    calculate_holiday(filtered_holidays)
  end

  private

  def calculate_holiday(holiday_list)
    regions_holidays = {}
    holidays = []
    holiday_list.each do |holiday|
      holidays << { date: holiday[:date], code: holiday[:name] }
      next if region.present? || has_regions == false
      regions_holidays = assign_regions_holidays(regions_holidays, holiday)
    end
    region.nil? && has_regions ? [holidays, regions_holidays.values] : holidays
  end

  def assign_regions_holidays(regions_holidays, holiday)
    holiday[:regions].each do |region_code|
      next unless region_code.to_s.starts_with?(country_code)
      regions_holidays[region_code] ||= { code: region_code, holidays: [] }
      regions_holidays[region_code][:holidays] << holiday[:name]
    end
    regions_holidays
  end

  def filtered_holidays
    filter.present? ? incoming_holidays : year_holidays
  end

  def invalid_region?
    has_regions == false && region.present?
  end

  def region_exists?
    return true if region.nil?
    Holidays.available_regions.include? country.to_sym
  end

  def valid_filter?
    return true if filter.nil?
    filter.eql?('upcoming')
  end

  def incoming_holidays
    Holidays.between(Time.zone.now, Time.zone.now + 2.years, country).first(10)
  end

  def year_holidays
    Holidays.between(beginning_of_year, end_of_year, country)
  end

  def region
    params[:region]
  end

  def filter
    params[:filter]
  end

  def check_params
    return if !invalid_region? && region_exists? && valid_filter?
    messages = {}
    messages[:country_attribute] = "Country doesn't have regions" if invalid_region?
    messages[:region_attribute] = "Region doesn't exist" unless region_exists?
    messages[:filter_attribute] = 'Wrong type of filter specified' unless valid_filter?

    raise InvalidParamTypeError.new(params, messages.values.first)
  end
end
