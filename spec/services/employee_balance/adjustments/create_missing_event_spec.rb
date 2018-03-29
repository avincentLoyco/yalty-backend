require "rails_helper"

RSpec.describe Adjustments::CreateMissingEvent do
  subject(:create_missing) { described_class.new(balance).call }

  let(:balance) do
    create(:employee_balance,
      employee: employee,
      resource_amount: adjustment_amount,
      balance_type: "manual_adjustment"
    )
  end

  let(:adjustment_amount) { 200 }
  let(:account) { create(:account) }
  let(:employee) { create(:employee, account: account) }
  let(:adjustment_events) { employee.events.where(event_type: :adjustment_of_balances) }
  let(:event_attributes) do
    adjustment_events.find_by(effective_at: balance.effective_at).attribute_values
  end


  before do
    create(:employee_attribute_definition,
      account: account,
      name: "adjustment",
      attribute_type: "Number"
    )
  end

  it "creates event" do
    expect { create_missing }
      .to change { adjustment_events.where(effective_at: balance.effective_at).count }.by(1)
  end

  it "creates event attributes" do
    create_missing
    expect(event_attributes["adjustment"].to_f).to eq(adjustment_amount)
  end

  context "when event already exist" do
    before { create_missing }

    it "doesn't create event" do
      expect { create_missing }.not_to change { adjustment_events.count }
    end
  end
end
