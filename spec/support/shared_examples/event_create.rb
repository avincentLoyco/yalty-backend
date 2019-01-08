RSpec.shared_examples "event create example" do
  it "creates the event" do
    expect(subject).to eq(event)
    expect(create_event_service_class_mock).to have_received(:new).with(
      params, params[:employee_attributes].to_a
    )
    expect(create_event_service_instance_mock).to have_received(:call)
  end
end
