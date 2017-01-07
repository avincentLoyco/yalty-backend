module Api::V1
  class CountryRepresenter
    attr_reader :holidays, :regions

    def initialize(holidays, regions)
      @holidays = holidays
      @regions = regions
    end

    def complete
      {}.tap do |response|
        response[:holidays] = holidays
        response[:regions] = regions if regions != []
      end
    end
  end
end
