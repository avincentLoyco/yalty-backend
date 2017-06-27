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
        last_event_for =
          employee
          .events
          .contract_types
          .where('effective_at <= ?', Time.zone.today)
          .order(:effective_at).last

        last_event_for.nil? || last_event_for.event_type.eql?('hired')
      end.map(&:id)

    CreateRegisteredWorkingTime.new(today, employees_ids).call
  end
end
