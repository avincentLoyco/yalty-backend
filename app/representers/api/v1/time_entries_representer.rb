module Api::V1
  class TimeEntriesRepresenter < BaseRepresenter
    def complete
      {
        start_time: time(resource.start_time),
        end_time: time(resource.end_time)
      }.merge(basic)
    end

    def time(date)
      date.to_s(:time)
    end
  end
end
