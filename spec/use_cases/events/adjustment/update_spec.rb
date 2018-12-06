require "rails_helper"

RSpec.describe Events::Adjustment::Update do
  include_context "event update context"
  include_context "end of contract balance handler context"

  let(:subject) do
    described_class.new(
      find_adjustment_balance: find_adjustment_balance_mock,
      update_event_service: update_event_service_class_mock,
      update_next_employee_balances_service: update_next_employee_balances_service_class_mock,
      find_and_destroy_eoc_balance: find_and_destroy_eoc_balance_mock,
      create_eoc_balance: create_eoc_balance_mock,
      find_first_eoc_event_after: find_first_eoc_event_after_mock,
    ).call(event, params)
  end

  let(:find_adjustment_balance_mock) do
    instance_double(Events::Adjustment::FindAdjustmentBalance, call: adjustment_balance)
  end

  let(:update_next_employee_balances_service_instance_mock) do
    instance_double(UpdateNextEmployeeBalances, call: true)
  end
  let(:update_next_employee_balances_service_class_mock) do
    class_double(
      UpdateNextEmployeeBalances, new: update_next_employee_balances_service_instance_mock
    )
  end

  let(:adjustment_balance) { build(:employee_balance) }

  before do
    allow(adjustment_balance).to receive(:update!)
  end

  it_behaves_like "event update example"
  it_behaves_like "end of contract balance handler for an event"

  it "updates adjustment balance" do
    subject
    expect(adjustment_balance).to have_received(:update!).with(
      resource_amount: updated_event.attribute_value("adjustment"),
      effective_at: updated_event.effective_at + Employee::Balance::MANUAL_ADJUSTMENT_OFFSET
    )
  end

  it "updates next employee balances" do
    subject
    expect(update_next_employee_balances_service_class_mock).to have_received(:new).with(
      adjustment_balance
    )
    expect(update_next_employee_balances_service_instance_mock).to have_received(:call)
  end
end
