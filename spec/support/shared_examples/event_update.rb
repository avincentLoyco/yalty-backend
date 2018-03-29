RSpec.shared_examples "event update example" do
  it "returns result from event_updater" do
    expect(subject).to eq(event_updater_instance.call)
  end

  it "calls UpdateEvent service" do
    subject
    expect(event_updater).to have_received(:new).with(event, params)
    expect(event_updater_instance).to have_received(:call)
  end
end
