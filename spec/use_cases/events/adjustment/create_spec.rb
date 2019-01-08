require "rails_helper"

RSpec.describe Events::Adjustment::Create do
  include_context "event create use case"
  include_context "end of contract balance handler context"

  subject do
    described_class.new(
      create_employee_balance_service: create_employee_balance_service_mock,
      create_event_service: create_event_service_class_mock,
      find_and_destroy_eoc_balance: find_and_destroy_eoc_balance_mock,
      create_eoc_balance: create_eoc_balance_mock,
      find_first_eoc_event_after: find_first_eoc_event_after_mock,
    ).call(params)
  end

  let(:create_employee_balance_service_mock) { class_double(CreateEmployeeBalance, call: true) }

  let(:account) { double(id: "account_id", vacation_category: vacation_category) }
  let(:vacation_category) { double(id: "time_off_category_id") }
  let(:account_id) { "account_id" }

  before do
    allow(event).to receive(:account) { account }
    allow(event).to receive(:attribute_value).with("adjustment") { 20 }
  end

  it_behaves_like "event create example"
  it_behaves_like "end of contract balance handler for an event"

  it "creates employee balance" do
    subject
    expect(create_employee_balance_service_mock).to have_received(:call).with(
      "time_off_category_id",
      event.employee_id,
      "account_id",
      balance_type: "manual_adjustment",
      resource_amount: 20,
      manual_amount: 0,
      effective_at: event.effective_at + Employee::Balance::MANUAL_ADJUSTMENT_OFFSET
    )
  end
end
