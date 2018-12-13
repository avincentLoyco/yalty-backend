module RegisteredWorkingTimes
  class PartOfEmploymentPeriodValidator
    include AppDependencies[
      custom_error: "errors.custom_error",
      verify_part_of_employment_period:
        "use_cases.registered_working_times.verify_part_of_employment_period",
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
      verify_part_of_employment_period.call(employee: employee, date: date)
    end

    def raise_error
      raise(
        custom_error,
        type: "registered_working_times",
        field: "date",
        messages: ["Date must be in employment period"],
        codes: ["registered_working_time.must_be_in_employment_period"]
      )
    end
  end
end
