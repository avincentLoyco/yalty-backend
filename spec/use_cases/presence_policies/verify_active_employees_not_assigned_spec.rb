require "rails_helper"

RSpec.describe PresencePolicies::VerifyActiveEmployeesNotAssigned do
  describe "#call" do
    subject { described_class.new.call(presence_policy: presence_policy) }

    let(:presence_policy) { create(:presence_policy, :with_presence_day) }

    context "when employees are empty" do
      let(:employees) { [] }
      it { expect { subject }.not_to raise_error }
    end

    context "when employees are not empty" do
      context "when there are active employees" do
        let(:employee) { create(:employee) }

        before do
          create(
            :employee_presence_policy,
            presence_policy: presence_policy,
            employee: employee,
            effective_at: Time.current
          )
        end

        it { expect { subject }.to raise_error API::V1::Exceptions::LockedError }
      end

      context "when there are only inactive employees" do
        let(:employee) { create(:employee, contract_end_at: Time.current - 1.day) }

        before do
          create(
            :employee_presence_policy,
            presence_policy: presence_policy,
            employee: employee,
            effective_at: Time.current - 3.days
          )
        end

        it { expect { subject }.not_to raise_error }
      end
    end
  end
end
