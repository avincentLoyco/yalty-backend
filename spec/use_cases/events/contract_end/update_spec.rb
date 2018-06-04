require "rails_helper"

RSpec.describe Events::ContractEnd::Update do
  include_context "event update context"

  before do
    use_case.contract_end_service = contract_end_handler

    allow(contract_end_handler).to receive(:call)
    allow(event_updater_instance).to receive(:call).and_return(event)
  end

  let(:contract_end_handler) { class_double("::ContractEnds::Update") }

  let(:account)  { create(:account) }
  let(:employee) { create(:employee, account: account) }
  let(:event_effective_at) { changed_event.effective_at }

  let(:event) do
    build_stubbed(:employee_event, event_type: "contract_end", employee: employee)
  end

  let(:changed_event) do
    event.dup.tap { |event| event.effective_at -= 5.days }
  end

  it_behaves_like "event update example"

  it "calls ContractEnds::Update service" do
    subject
    expect(contract_end_handler).to have_received(:call)
      .with(
        employee: event.employee,
        new_contract_end_date: changed_event.effective_at,
        old_contract_end_date: event.effective_at
      )
  end
end
