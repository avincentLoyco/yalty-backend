require "rails_helper"

RSpec.describe CreateManualAdjustmentForEmployee do
  let_it_be(:account) { create(:account) }
  let_it_be(:employee) { create(:employee, account: account) }
  let_it_be(:user) { create(:account_user, employee: employee, account: account) }

  let_it_be(:hired_at) { Time.new(2016, 1, 1) }
  let_it_be(:contract_changed_at) { Time.new(2017, 1, 1) }

  let_it_be(:vacation_category) { account.time_off_categories.vacation.first }

  let_it_be(:first_time_off_policy) do
    create(:time_off_policy, time_off_category: vacation_category, amount: 10200)
  end
  let_it_be(:hired_event) do
    employee.events.first
  end
  let_it_be(:first_employee_time_off_policy) do
    create(:employee_time_off_policy,
      employee: employee,
      time_off_policy: first_time_off_policy,
      effective_at: hired_at,
      employee_event: hired_event,
      occupation_rate: 0.8,
    )
  end

  let_it_be(:second_time_off_policy) do
    create(:time_off_policy, time_off_category: vacation_category, amount: 10200)
  end
  let_it_be(:contract_change_event) do
    create(:employee_event,
      event_type: "work_contract",
      effective_at: contract_changed_at,
      employee: employee,
    )
  end
  let_it_be(:second_employee_time_off_policy) do
    create(:employee_time_off_policy,
      employee: employee,
      time_off_policy: second_time_off_policy,
      effective_at: contract_changed_at,
      employee_event: contract_change_event,
      occupation_rate: 1.0,
    )
  end

  let_it_be(:expected_value) { 0.8 * 10200 }

  before { Account.current = account }

  subject { described_class.new(account, user.email).call }

  it { expect { subject }.to change { employee.employee_balances.count }.by 1 }
  it { expect { subject }.to change { employee.events.count }.by 1 }
  it do
    subject
    last_employee_balance = employee.employee_balances.order("effective_at asc").last
    expect(last_employee_balance.resource_amount).to eq expected_value
  end
end
