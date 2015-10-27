module V1
  class PresenceDayRepresenter < BaseRepresenter
    def complete
      {
        order: resource.order,
        hours: resource.hours
      }
        .merge(basic)
    end
  end
end
