module Api::V1
  class CountryRepresenter
    attr_reader :country

    def initialize(country)
      unless HolidayPolicy::COUNTRIES_WITHOUT_REGIONS.include?(country)
        country = "#{country}_"
      end
      @country = country
    end

    def complete
      holidays, regions_with_holidays = HolidaysForCountry.new(country).call
      {
        holidays: holidays,
        regions: regions_with_holidays
      }
    end
  end
end
