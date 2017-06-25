namespace :employee_events do
  desc 'fix pairs of contract end and rehired in the same day'
  task fix_invalid_contract_end_and_hire_pairs: :environment do
    invalid_events = Employee::Event.all.reject(&:valid?)
    grouped_events = invalid_events.group_by { |event| [event[:employee_id], event[:effective_at]] }

    grouped_events.map do |_params, events|
      hired = events.select { |event| event[:event_type].eql?('hired') }.first
      hired.effective_at = hired.effective_at + 1.day
      updated_tables = HandleMapOfJoinTablesToNewHiredDate.new(
        hired.employee, hired.effective_at, hired.effective_at_was
      ).call
      ActiveRecord::Base.transaction do
        updated_tables[:join_tables].map(&:save!)
        updated_tables[:employee_balances].map(&:save!)
        hired.save!
      end
    end
  end
end
