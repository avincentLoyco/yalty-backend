RSpec.shared_context "event update context" do
  let(:subject) do
    described_class
      .new(update_event_service: update_event_service_class_mock)
      .call(event, params)
  end

  let(:event) { build(:employee_event, event_type: "adjustment_of_balances") }
  let(:updated_event) { build(:employee_event, event_type: "adjustment_of_balances") }
  let(:params) do
    { effective_at: Time.current }
  end
  let(:effective_at) { params[:effective_at] }

  let(:update_event_service_class_mock) do
    class_double(UpdateEvent, new: update_event_service_instance_mock)
  end
  let(:update_event_service_instance_mock) { instance_double(UpdateEvent, call: updated_event) }
end
