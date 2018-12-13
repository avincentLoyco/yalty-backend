module RegisteredWorkingTimes
  class PartOfEmploymentPeriodValidator
    include AppDependencies[
      custom_error: "errors.custom_error",
    ]

    def call(employee:, date:)
      @employee = employee
      @date = date
      validate!
    end

    private

    attr_reader :employee, :date

    def validate!
      raise_error unless part_of_employment_period?
    end

    def part_of_employment_period?
      last_event_for = employee.events.contract_types.where("effective_at < ?", date)
        .order(:effective_at).last
      last_event_for.nil? || last_event_for.event_type.eql?("hired")
    end

    def raise_error
      raise(
        CustomError,
        type: "registered_working_times",
        field: "date",
        messages: ["Date must be in employment period"],
        codes: ["registered_working_time.must_be_in_employment_period"]
      )
    end
  end
end
