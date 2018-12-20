class AddRegisteredWorkingTimes < ActiveJob::Base
  queue_as :registered_working_times
  include AppDependencies[
    verify_part_of_employment_period:
      "use_cases.registered_working_times.verify_part_of_employment_period",
  ]

  def perform
    today = Time.zone.today
    yesterday = today - 1

    employees_with_working_hours_ids =
      Employee
      .joins(:registered_working_times)
      .where(registered_working_times: { date: yesterday })
      .pluck(:id)

    # NOTE: registered working time should be created till the last day of work
    # (including the last day)
    employees_ids =
      Employee.where.not(id: employees_with_working_hours_ids).select do |employee|
        verify_part_of_employment_period.call(
          employee: employee,
          date: today
        )
      end.map(&:id)

    CreateRegisteredWorkingTime.new(yesterday, employees_ids).call
  end
end
