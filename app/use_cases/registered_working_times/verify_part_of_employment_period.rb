module RegisteredWorkingTimes
  class VerifyPartOfEmploymentPeriod
    def call(employee:, date:)
      last_event_for = employee
        .events
        .contract_types
        .where("effective_at < ?", date)
        .order(:effective_at)
        .last

      last_event_for.nil? || last_event_for.event_type.eql?("hired")
    end
  end
end
