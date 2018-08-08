namespace :employee_event do
  desc "Fix balances for work contract events"
  task fix_time_off_balances: :environment do
    Account::User.current = Account::User.find_by email: ENV["YALTY_ACCESS_EMAIL"]

    Employee::Event
      .where(Employee::Event.arel_table[:effective_at].gteq(Rails.configuration.migration_date))
      .where(event_type: "work_contract")
      .each do |event|
        next if event.employee_time_off_policy.nil? || event.employee.can_be_hired?

        UpdateEtopForEvent.new(
          event.id,
          event.employee_time_off_policy.time_off_policy.amount,
          event.effective_at
        ).call
      end
  end
end
