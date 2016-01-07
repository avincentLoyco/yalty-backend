module Api::V1
  class PresenceDayRepresenter < BaseRepresenter
    def complete
      {
        order: resource.order,
        minutes: resource.minutes
      }
        .merge(basic)
        .merge(relationships)
    end

    def relationships
      {
        time_entries: time_entries_json
      }
    end

    def time_entries_json
      resource.time_entries.map do |attribute|
        TimeEntriesRepresenter.new(attribute).basic
      end
    end
  end
end
