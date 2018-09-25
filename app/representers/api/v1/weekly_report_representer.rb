module Api::V1
  class WeeklyReportRepresenter < BaseRepresenter
    def complete
      {}.merge(basic)
    end
  end
end
