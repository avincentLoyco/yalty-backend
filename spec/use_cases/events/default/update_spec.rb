require "rails_helper"

RSpec.describe Events::Default::Update do
  include_context "event update context"

  it_behaves_like "event update example"

  describe ".call" do
    let(:fake_instance) { instance_double(described_class, call: true) }

    before do
      allow(described_class).to receive(:new).and_return(fake_instance)
    end

    it "delegates to instance" do
      described_class.call(:something, :params)
      expect(described_class).to have_received(:new).with(:something, :params)
      expect(fake_instance).to have_received(:call).with(no_args)
    end
  end
end
