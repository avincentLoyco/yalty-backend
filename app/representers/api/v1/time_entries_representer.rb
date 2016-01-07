module Api::V1
  class TimeEntriesRepresenter < BaseRepresenter
    def complete
      {
        start_time: resource.start_time,
        end_time: resource.end_time
      }
        .merge(basic)
        .merge(relationships)
    end

    def relationships
      {
        presence_day: presence_day_json
      }
    end

    def presence_day_json
      PresenceDayRepresenter.new(resource.presence_day).basic
    end
  end
end
