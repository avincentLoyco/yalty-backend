require "rails_helper"

RSpec.describe Notifications::Recipients::TimeOffRequest do
  describe "#call" do
    subject(:recipient) { described_class.call(resource) }

    let(:resource) { instance_double(TimeOff, employee: employee) }

    let(:employee) { instance_double(Employee, account: account) }

    let(:account) { instance_double(Account, admins: %i(admin owner)) }

    context "when there is manager assigned" do
      before do
        allow(resource).to receive(:manager).and_return(:manager)
      end

      it "returns manager" do
        expect(recipient).to eq(:manager)
      end
    end

    context "when there is no manager assigned" do
      before do
        allow(resource).to receive(:manager).and_return(nil)
      end

      it "returns all admins and managers" do
        expect(recipient).to contain_exactly(:admin, :owner)
      end
    end
  end
end
