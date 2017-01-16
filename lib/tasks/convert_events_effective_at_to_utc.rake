task convert_events_effective_at_to_utc: [:environment] do
  Employee::Event.all.each do |event|
    timezone = event.account.timezone
    next if timezone.eql?('UTC')
    new_effective_at = event.effective_at.in_time_zone(timezone).to_date
    event.update_attribute(:effective_at, new_effective_at)
  end
end
