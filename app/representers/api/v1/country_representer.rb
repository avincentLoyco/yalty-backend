module Api::V1
  class CountryRepresenter
    attr_reader :country, :has_regions

    def initialize(country)
      @country = country
      @has_regions = !HolidayPolicy::COUNTRIES_WITHOUT_REGIONS.include?(country)
    end

    def complete
      holidays, regions_with_holidays = HolidaysForCountry.new(country, has_regions).call
      {
        holidays: holidays,
        regions: regions_with_holidays
      }
    end
  end
end
