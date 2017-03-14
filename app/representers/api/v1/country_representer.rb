module Api::V1
  class CountryRepresenter < BaseRepresenter
    attr_reader :country, :has_regions

    def initialize(country)
      @country = country
      @has_regions = HolidayPolicy.country_with_regions?(country)
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
