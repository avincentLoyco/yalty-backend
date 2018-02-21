desc "Add active attribute to existing employee events"
task add_active_attr_to_events: :environment do
  events = %w[hired work_contract contract_end]
  Employee::Event
    .where("created_at < ?", Date.new(2018, 1, 1))
    .where(event_type: events)
    .each do |event|
      event.update_attribute("active", false)
    end
end
