class DeleteTypeInPeriod
  pattr_initialize [:period_to_delete!, :event_type, :employee]

  def self.call(period_to_delete:, event_type: nil, employee: nil)
    new(period_to_delete: period_to_delete, event_type: event_type, employee: employee).call
  end

  def call
    return if events_in_period.empty?
    events_in_period.each do |event|
      DeleteEvent.call(event)
    end
  end

  private

  def events_in_period
    # TODO: Change to Event::FindInPeriod in the future, when event namespace is added
    @events_in_period ||= FindInPeriod.call(
      period_to_search: period_to_delete,
      event_type: event_type,
      employee: employee
    )
  end
end
