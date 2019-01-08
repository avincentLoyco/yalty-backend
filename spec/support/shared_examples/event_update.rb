RSpec.shared_examples "event update example" do
  it "updates event" do
    expect(subject).to eq(updated_event)
    expect(update_event_service_class_mock).to have_received(:new).with(event, params)
    expect(update_event_service_instance_mock).to have_received(:call)
  end
end
