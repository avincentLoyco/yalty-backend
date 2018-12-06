RSpec.shared_examples "event destroy example" do
  it "deletes the event" do
    subject
    expect(delete_event_service_class_mock).to have_received(:new).with(event)
    expect(delete_event_service_instance_mock).to have_received(:call)
  end
end
