require "rails_helper"

RSpec.describe Events::ContractEnd::Create do
  include_context "event create use case"

  let(:contract_end_handler) { class_double("::ContractEnd::Create") }

  let(:employee_attributes) { nil }

  let(:event) { build_stubbed(:employee_event) }

  before do
    use_case.contract_end_service = contract_end_handler
    allow(contract_end_handler).to receive(:call)
    allow(event_creator_instance).to receive(:call).and_return(event)
  end

  it "calls ContractEnd::Create service" do
    subject
    expect(contract_end_handler).to have_received(:call)
      .with(employee: event.employee, contract_end_date: event.effective_at)
  end
end
