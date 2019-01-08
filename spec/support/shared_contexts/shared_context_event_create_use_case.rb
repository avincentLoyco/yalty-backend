RSpec.shared_context "event create use case" do
  subject do
    described_class
      .new(create_event_service: create_event_service_class_mock)
      .call(params)
  end

  let(:create_event_service_class_mock) do
    class_double(CreateEvent, new: create_event_service_instance_mock)
  end
  let(:create_event_service_instance_mock) do
    instance_double(CreateEvent, call: event)
  end

  let(:event) { build(:employee_event) }
  let(:params) do
    { effective_at: Time.current, data: :data, employee: { id: event.employee.id } }
  end
  let(:effective_at) { params[:effective_at] }
end
