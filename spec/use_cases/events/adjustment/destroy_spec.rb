require "rails_helper"

RSpec.describe Events::Adjustment::Destroy do
  include_context "event destroy context"

  it_behaves_like "event destroy example"

  before do
    allow(DestroyEmployeeBalance).to receive(:new).and_call_original
  end

  let!(:adjustment_balance) do
    create(:employee_balance,
      employee: employee,
      resource_amount: 200,
      time_off_category: vacation_category,
      balance_type: "manual_adjustment",
      effective_at: event.effective_at
    )
  end

  let(:account) { create(:account) }
  let(:vacation_category) { account.vacation_category }
  let(:employee) { create(:employee, account: account) }

  let(:event) do
    build_stubbed(:employee_event, event_type: "adjustment_of_balances", employee: employee)
  end

  it "destroy balance" do
    expect{ subject }
      .to change { Employee::Balance.exists?(adjustment_balance.id) }
      .from(true)
      .to(false)
  end

  it "calls DestroyEmployeeBalance" do
    subject
    expect(DestroyEmployeeBalance).to have_received(:new).with(adjustment_balance)
  end
end
