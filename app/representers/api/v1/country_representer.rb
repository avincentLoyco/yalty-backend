module Api::V1
  class CountryRepresenter
    attr_reader :holidays, :regions

    def initialize(holidays, regions = nil)
      @holidays = holidays
      @regions = regions
    end

    def complete
      {
        holidays: holidays,
        regions: regions
      }
    end

    def only_holidays
      {
        holidays: holidays
      }
    end
  end
end
