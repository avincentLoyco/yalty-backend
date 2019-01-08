require "rails_helper"

RSpec.describe Events::ContractEnd::Destroy do
  include_context "event destroy context"

  subject do
    described_class
      .new(
        find_and_destroy_eoc_balance: find_and_destroy_eoc_balance_mock,
        delete_event_service: delete_event_service_class_mock,
      )
      .call(event)
  end

  let(:etop) { build(:employee_time_off_policy, employee_event: event) }

  let(:find_and_destroy_eoc_balance_mock) do
    instance_double(Balances::EndOfContract::FindAndDestroy, call: true)
  end

  before do
    etop
    allow(event).to receive(:save!)
  end

  it_behaves_like "event destroy example"

  it "unassigns employee time off policy from event" do
    subject
    expect(event.employee_time_off_policy).to eq(nil)
  end

  it "destroys end_of_contract balance" do
    subject
    expect(find_and_destroy_eoc_balance_mock).to have_received(:call).with(
      employee: event.employee, eoc_date: event.effective_at
    )
  end
end
