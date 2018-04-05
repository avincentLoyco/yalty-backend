require "rails_helper"

RSpec.describe Events::Adjustment::Update do
  include_context "event update context"

  it_behaves_like "event update example"

  let_it_be(:account) { create(:account) }
  let_it_be(:vacation_category) { account.vacation_category }
  let_it_be(:time_off_policy) { create(:time_off_policy, time_off_category: vacation_category) }
  let_it_be(:employee) { create(:employee, account: account) }

  let!(:adjustment_balance) do
    Employee::Balance.create!(
      employee: employee,
      resource_amount: 200,
      time_off_category: vacation_category,
      balance_type: "manual_adjustment",
      effective_at: event.effective_at + Employee::Balance::MANUAL_ADJUSTMENT_OFFSET
    )
  end

  let(:account)                  { create(:account) }
  let(:vacation_category)        { account.vacation_category }
  let(:employee)                 { create(:employee, account: account) }
  let(:balance_updater)          { class_double("UpdateNextEmployeeBalances") }
  let(:balance_updater_instance) { instance_double("UpdateNextEmployeeBalances") }

  let(:event) do
    build_stubbed(:employee_event, event_type: "adjustment_of_balances", employee: employee)
  end

  let(:changed_event) do
    event.dup.tap{ |event| event.effective_at += 1.day }
  end

  before_all do
    create(:employee_time_off_policy,
      employee: employee, time_off_policy: time_off_policy,
      effective_at: Date.new(2018,1,1)
    )
  end

  before do
    use_case.next_balance_updater = balance_updater

    allow(balance_updater).to receive(:new).and_return(balance_updater_instance)
    allow(balance_updater_instance).to receive(:call)
    allow(event_updater_instance).to receive(:call).and_return(changed_event)
    allow(changed_event).to receive(:attribute_value).with("adjustment").and_return(30)
  end

  it "updates balance amount" do
    expect{ subject }.to change { adjustment_balance.reload.resource_amount }.to(30)
  end

  it "updates balance effective_at" do
    expect{ subject }.to change { adjustment_balance.reload.effective_at }
  end

  it "calls UpdateNextEmployeeBalances" do
    subject
    expect(balance_updater).to have_received(:new).with(adjustment_balance)
    expect(balance_updater_instance).to have_received(:call)
  end
end
