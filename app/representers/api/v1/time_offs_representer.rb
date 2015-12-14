module Api::V1
  class TimeOffsRepresenter < BaseRepresenter
    def complete
      {
        start_time: resource.start_time,
        end_time: resource.end_time
      }
        .merge(basic)
    end
  end
end
