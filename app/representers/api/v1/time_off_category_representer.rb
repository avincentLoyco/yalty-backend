module Api::V1
  class TimeOffCategoryRepresenter < BaseRepresenter
    attr_reader :resource, :periods

    def initialize(resource, periods = [])
      @resource = resource
      @periods = periods
    end

    def complete
      {
        name: resource.name,
        system: resource.system,
      }
        .merge(basic)
        .merge(dates)
    end

    def dates
      return {} if periods.blank?
      {
        periods: periods,
      }
    end
  end
end
