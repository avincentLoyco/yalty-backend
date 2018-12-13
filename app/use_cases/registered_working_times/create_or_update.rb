# frozen_string_literal: true

module RegisteredWorkingTimes
  class CreateOrUpdate
    include AppDependencies[
      part_of_employment_period_validator:
        "validators.registered_working_times.part_of_employment_period",
    ]

    def call(registered_working_time:, employee:, date:, params:)
      @registered_working_time = registered_working_time
      @employee = employee
      @date = date

      validate!

      registered_working_time.update!(params.slice(:comment, :time_entries))
    end

    private

    attr_reader :registered_working_time, :employee, :date

    def validate!
      part_of_employment_period_validator.call(employee: employee, date: date)
    end
  end
end
