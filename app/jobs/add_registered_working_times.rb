class AddRegisteredWorkingTimes < ActiveJob::Base
  queue_as :registered_working_times

  def perform
    today = Time.zone.today - 1

    employees_with_working_hours_ids =
      Employee
      .joins(:registered_working_times)
      .where(registered_working_times: { date: today })
      .pluck(:id)

    employees_ids =
      Employee.where.not(id: employees_with_working_hours_ids).select do |employee|
        employee.last_event_for.nil? || employee.last_event_for.event_type.eql?('hired')
      end.map(&:id)

    CreateRegisteredWorkingTime.new(today, employees_ids).call
  end
end
