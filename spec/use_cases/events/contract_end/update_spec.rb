require "rails_helper"

RSpec.describe Events::ContractEnd::Update do
  describe "#call" do
    subject do
      described_class
        .new(
          assign_employee_top_to_event: assign_employee_top_to_event_mock,
          update_event_service: update_event_service_class_mock
        )
        .call(event, params)
    end

    let(:params) { { mocked_param: "mocked_param" } }
    let(:event)  { build(:employee_event) }

    let(:assign_employee_top_to_event_mock) do
      instance_double(Events::ContractEnd::AssignEmployeeTopToEvent, call: true)
    end

    let(:update_event_service_instance_mock) { instance_double(UpdateEvent, call: event) }
    let(:update_event_service_class_mock) do
      class_double(UpdateEvent, new: update_event_service_instance_mock)
    end

    it { expect(subject).to eq(event) }

    it "updates an event" do
      subject
      expect(update_event_service_class_mock).to have_received(:new).with(event, params)
      expect(update_event_service_instance_mock).to have_received(:call)
    end

    it "assigns time off policy to the event" do
      subject
      expect(assign_employee_top_to_event_mock).to have_received(:call).with(event)
    end
  end
end
