require "rails_helper"

RSpec.describe PresencePolicies::VerifyNotDefaultFullTime do
  describe "#call" do
    subject { described_class.new.call(presence_policy: presence_policy) }

    let(:presence_policy) do
      instance_double("PresencePolicy", default_full_time?: default_full_time)
    end

    context "when presence_policy is default full time" do
      let(:default_full_time) { true }
      it { expect { subject }.to raise_error API::V1::Exceptions::CustomError }
    end

    context "when presence_policy is not default full time" do
      let(:default_full_time) { false }
      it { expect { subject }.not_to raise_error }
    end
  end
end
