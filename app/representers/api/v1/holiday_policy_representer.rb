module Api::V1
  class HolidayPolicyRepresenter < BaseRepresenter
    def complete
      {
        name: resource.name,
        country: resource.country,
        region: resource.region
      }
        .merge(basic)
        .merge(relationships)
    end

    def relationships
      holidays = resource.holidays.map do |holiday|
        HolidayRepresenter.new(holiday).basic
      end
      {
        holidays: holidays
      }
    end
  end
end
