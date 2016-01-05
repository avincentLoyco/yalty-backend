module Api::V1
  class PresenceDayRepresenter < BaseRepresenter
    def complete
      {
        order: resource.order,
        minutes: resource.minutes
      }
        .merge(basic)
    end
  end
end
