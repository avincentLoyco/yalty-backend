require "rails_helper"

RSpec.describe Events::Adjustment::Create do
  include_context "event create use case"

  let(:balance_handler) { class_double("CreateEmployeeBalance") }
  let(:effective_at) { Date.new(2105,02,02) }
  let(:event) { build_stubbed(:employee_event) }
  let(:account) { double(id: "account_id", vacation_category: vacation_category) }
  let(:vacation_category) { double(id: "time_off_category_id") }
  let(:account_id) { "account_id" }

  before do
    use_case.balance_handler = balance_handler

    allow(event).to receive(:account) { account }
    allow(event).to receive(:attribute_value).with("adjustment") { 20 }
    allow(event_creator_instance).to receive(:call).and_return(event)
    allow(balance_handler).to receive(:call)
  end

  it "calls CreateEmployeeBalance" do
    subject
    expect(balance_handler).to have_received(:call).with(
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
