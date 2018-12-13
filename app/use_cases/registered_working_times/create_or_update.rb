# frozen_string_literal: true

module RegisteredWorkingTimes
  class CreateOrUpdate
    include AppDependencies[
      part_of_employment_period_validator:
        "validators.registered_working_times.part_of_employment_period",
      registered_working_time_model: "models.registered_working_time",
    ]

    def call(employee:, date:, params:)
      @employee = employee
      @date = date

      validate!

      registered_working_time.update!(
        comment: params[:comment],
        time_entries: filtered_attributes(params),
      )
    end

    private

    attr_reader :employee, :date

    def registered_working_time
      @registered_working_time ||= registered_working_time_model.find_or_initialize_by(
        employee: employee, date: date
      )
    end

    def validate!
      part_of_employment_period_validator.call(employee: employee, date: date)
    end

    def filtered_attributes(attributes)
      return [] if attributes[:time_entries].nil?
      attributes[:time_entries].map do |entry|
        next unless entry.is_a?(Hash)
        entry.except("type")
      end
    end
  end
end
