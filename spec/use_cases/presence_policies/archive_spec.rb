# frozen_string_literal: true

require "rails_helper"

RSpec.describe PresencePolicies::Archive do
  describe "#call" do
    subject do
      described_class.new(
        verify_active_employees_not_assigned: verify_active_employees_not_assigned_mock,
        verify_not_default_full_time: verify_not_default_full_time_mock,
      )
      .call(
        presence_policy: presence_policy,
      )
    end

    let_it_be(:account) { create(:account) }
    let!(:presence_policy) { create(:presence_policy, account: account) }
    let!(:presence_policies_count) { PresencePolicy.count }

    let(:verify_active_employees_not_assigned_mock) do
      instance_double(PresencePolicies::VerifyActiveEmployeesNotAssigned, call: true)
    end
    let(:verify_not_default_full_time_mock) do
      instance_double(PresencePolicies::VerifyNotDefaultFullTime, call: true)
    end

    context "when no assigned employees and policy is not the default full time one" do
      it "destroys the present policy" do
        expect { subject }.to change { presence_policy.reload.archived }.from(false).to(true)
        expect(verify_active_employees_not_assigned_mock).to have_received(:call)
        expect(verify_not_default_full_time_mock).to have_received(:call)
      end
    end

    context "when some employees assigned" do
      let(:verify_active_employees_not_assigned_mock) do
        instance_double(PresencePolicies::VerifyActiveEmployeesNotAssigned)
      end

      before do
        allow(verify_active_employees_not_assigned_mock).to receive(:call).and_raise(StandardError)
      end

      it "doesn't destroy the presence policy" do
        expect { subject }.to raise_error StandardError
        expect(verify_active_employees_not_assigned_mock).to have_received(:call)
        expect(verify_not_default_full_time_mock).not_to have_received(:call)
        expect(PresencePolicy.count).to eq presence_policies_count
      end
    end

    context "when policy is marked as default full time" do
      let(:verify_not_default_full_time_mock) do
        instance_double(PresencePolicies::VerifyNotDefaultFullTime)
      end

      before do
        allow(verify_not_default_full_time_mock).to receive(:call).and_raise(StandardError)
      end

      it "doesn't destroy the presence_policy" do
        expect { subject }.to raise_error StandardError
        expect(verify_active_employees_not_assigned_mock).to have_received(:call)
        expect(verify_not_default_full_time_mock).to have_received(:call)
        expect(PresencePolicy.count).to eq presence_policies_count
        account.reload
        expect(account.default_full_time_presence_policy_id).not_to eq nil
        expect(account.standard_day_duration).not_to eq nil
      end
    end
  end
end
