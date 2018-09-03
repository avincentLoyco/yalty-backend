require "rails_helper"

RSpec.describe Notifications::Recipients::TimeOffProcessed do
  describe "#call" do
    subject(:recipient) { described_class.call(resource) }

    let(:resource) { instance_double(TimeOff) }

    before do
      allow(resource).to receive(:user).and_return(:user)
    end

    it "returns employee" do
      expect(recipient).to eq(:user)
    end
  end
end
