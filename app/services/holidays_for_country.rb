class HolidaysForCountry
  attr_reader :country, :beginning_of_year, :end_of_year, :country_code

  def initialize(country, has_regions)
    @country = has_regions ? "#{country}_" : country
    @country_code = country
    @beginning_of_year = Time.zone.now.beginning_of_year
    @end_of_year = Time.zone.now.end_of_year
  end

  def call
    regions_holidays = {}
    holidays = []
    Holidays.between(beginning_of_year, end_of_year, country).each do |holiday|
      holiday_name = HolidaysCodeName.get_name_code(holiday[:name])
      holidays << { date: holiday[:date], code: holiday_name }
      holiday[:regions].each do |region_code|
        next unless region_code.to_s.starts_with?(country)
        regions_holidays[region_code] ||= { code: region_code, holidays: [] }
        regions_holidays[region_code][:holidays] << holiday_name
      end
    end
    [holidays, regions_holidays.values]
  end
end
