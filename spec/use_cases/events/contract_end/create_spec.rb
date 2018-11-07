require "rails_helper"

RSpec.describe Events::ContractEnd::Create do
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

    let(:params)                          { { employee_attributes: ["employee_attributes_mock"] } }
    let(:contract_end_service_class_mock) { class_double(ContractEnds::Create, call: true) }

    let(:assign_employee_top_to_event_mock) do
      instance_double(Events::ContractEnd::AssignEmployeeTopToEvent, call: true)
    end

    let(:event)                              { build(:employee_event) }
    let(:create_event_service_instance_mock) { instance_double(CreateEvent, call: event) }
    let(:create_event_service_class_mock) do
      class_double(CreateEvent, new: create_event_service_instance_mock)
    end

    it { expect(subject).to eq(event) }

    it "creates an event" do
      subject
      expect(create_event_service_class_mock).to have_received(:new).with(
        params, params[:employee_attributes].to_a
      )
      expect(create_event_service_instance_mock).to have_received(:call)
    end

    it "assigns time off policy to the event" do
      subject
      expect(assign_employee_top_to_event_mock).to have_received(:call).with(event)
    end

    it "handles contract end" do
      subject
      expect(contract_end_service_class_mock).to have_received(:call).with(
        employee: event.employee,
        contract_end_date: event.effective_at,
        event_id: event.id,
      )
    end
  end
end
