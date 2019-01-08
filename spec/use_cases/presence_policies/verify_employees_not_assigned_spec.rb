require "rails_helper"

RSpec.describe PresencePolicies::VerifyEmployeesNotAssigned do
  describe "#call" do
    subject { described_class.new.call(resource: resource) }

    context "when resource doesn't respond to 'employees'" do
      let(:resource) { double }

      it { expect { subject }.not_to raise_error }
    end

    context "when resource respond to 'employees'" do
      let(:resource) { instance_double("PresencePolicy", employees: employees) }

      context "when employees are empty" do
        let(:employees) { [] }
        it { expect { subject }.not_to raise_error }
      end

      context "when employees are not empty" do
        let(:employees) { [1, 2, 3] }
        it { expect { subject }.to raise_error API::V1::Exceptions::LockedError }
      end
    end
  end
end
