namespace :employee_event do
  desc "Create missing adjustment of balance events for existing manual adjustment balances"
  task create_missing_adjustment_events: :environment do
    Employee::Balance
      .where(balance_type: :manual_adjustment)
      .includes(employee: :account)
      .find_each { |balance| Adjustments::CreateMissingEvent.new(balance).call }
  end
end
