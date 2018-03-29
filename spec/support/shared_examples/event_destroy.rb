RSpec.shared_examples "event destroy example" do
  it "returns result from event_destroyer" do
    expect(subject).to eq(event_destroyer_instance.call)
  end

  it "calls DestroyEvent service" do
    subject
    expect(event_destroyer).to have_received(:new).with(event)
    expect(event_destroyer_instance).to have_received(:call)
  end
end
