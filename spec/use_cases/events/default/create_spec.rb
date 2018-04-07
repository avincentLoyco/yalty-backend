require "rails_helper"

RSpec.describe Events::Default::Create do

  include_context "event create use case"

  it "returns result from event_creator" do
    expect(subject).to eq(event_creator_instance.call)
  end

  describe ".call" do
    let(:fake_instance) { instance_double(described_class, call: true) }

    before do
      allow(described_class).to receive(:new).and_return(fake_instance)
    end

    it "delegates to instance" do
      described_class.call(:something)
      expect(described_class).to have_received(:new).with(:something)
      expect(fake_instance).to have_received(:call).with(no_args)
    end
  end

  context "when employee_attributes are not present" do
    it "calls CreateEvent service" do
      subject
      expect(event_creator).to have_received(:new).with(params, [])
      expect(event_creator_instance).to have_received(:call)
    end
  end

  context "when employee_attributes present" do
    let(:employee_attributes) { { name: :name, age: 10 } }

    it "calls CreateEvent service" do
      subject
      expect(event_creator).to have_received(:new).with(params, employee_attributes.to_a)
      expect(event_creator_instance).to have_received(:call)
    end
  end
end
