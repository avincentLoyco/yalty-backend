require "rails_helper"

RSpec.describe Events::ContractEnd::Create do
  include_context "event create use case"

  describe "#call" do
    subject do
      described_class
        .new(
          assign_employee_top_to_event: assign_employee_top_to_event_mock,
          contract_end_service: contract_end_service_class_mock,
          create_event_service: create_event_service_class_mock
        )
        .call(params)
    end

    let(:contract_end_service_class_mock) { class_double(ContractEnds::Create, call: true) }

    let(:assign_employee_top_to_event_mock) do
      instance_double(Events::ContractEnd::AssignEmployeeTopToEvent, call: true)
    end

    it_behaves_like "event create example"

    it "assigns time off policy to the event" do
      subject
      expect(assign_employee_top_to_event_mock).to have_received(:call).with(event)
    end

    it "handles contract end" do
      subject
      expect(contract_end_service_class_mock).to have_received(:call).with(
        employee: event.employee,
        contract_end_date: event.effective_at,
        eoc_event_id: event.id,
      )
    end
  end
end
