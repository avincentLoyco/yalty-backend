RSpec.shared_context "event destroy context" do
  subject do
    described_class
      .new(delete_event_service: delete_event_service_class_mock)
      .call(event)
  end

  let(:event) { build(:employee_event) }
  let(:effective_at) { event.effective_at }

  let(:delete_event_service_class_mock) do
    class_double(DeleteEvent, new: delete_event_service_instance_mock)
  end
  let(:delete_event_service_instance_mock) do
    instance_double(DeleteEvent, call: true)
  end
end
