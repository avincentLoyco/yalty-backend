module Api::V1
  class HolidayPolicyRepresenter < BaseRepresenter
    def complete
      {
        name: resource.name,
        country: resource.country,
        region: resource.region
      }
        .merge(basic)
    end
  end
end
