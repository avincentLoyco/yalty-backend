require "rails_helper"

RSpec.describe Events::WorkContract::Destroy do
  subject do
    described_class
      .new(delete_event_service: delete_event_service_class_mock)
      .call(event)
  end

  let(:event) { build(:employee_event) }
  let(:delete_event_service_class_mock) do
    class_double(DeleteEvent, new: delete_event_service_instance_mock)
  end
  let(:delete_event_service_instance_mock) do
    instance_double(DeleteEvent, call: true)
  end

  before { subject }

  it { expect(delete_event_service_class_mock).to have_received(:new).with(event) }
  it { expect(delete_event_service_instance_mock).to have_received(:call) }
end
