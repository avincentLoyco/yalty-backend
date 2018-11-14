require "rails_helper"

RSpec.describe Events::WorkContract::Update do
  subject do
    described_class
      .new(update_event_service: update_event_service_class_mock)
      .call(event, params)
  end

  let(:event) { build(:employee_event) }
  let(:params) { { some_param: "some_param" } }
  let(:update_event_service_class_mock) do
    class_double(UpdateEvent, new: update_event_service_instance_mock)
  end
  let(:update_event_service_instance_mock) do
    instance_double(UpdateEvent, call: true)
  end

  before { subject }

  it { expect(update_event_service_class_mock).to have_received(:new).with(event, params) }
  it { expect(update_event_service_instance_mock).to have_received(:call) }
end
