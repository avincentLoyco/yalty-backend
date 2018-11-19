# frozen_string_literal: true

require "rails_helper"

RSpec.describe PresenceDays::Create do
  describe "#call" do
    subject do
      described_class.new(
        update_default_full_time: update_default_full_time_mock,
        verify_employees_not_assigned: verify_employees_not_assigned_mock,
      )
      .call(
        params: params,
        presence_policy: presence_policy,
      )
    end

    let!(:presence_policy) { create(:presence_policy) }
    let(:params) do
      { order: 1 }
    end

    let(:update_default_full_time_mock) do
      instance_double(PresencePolicies::UpdateDefaultFullTime, call: true)
    end
    let(:verify_employees_not_assigned_mock) do
      instance_double(PresencePolicies::VerifyEmployeesNotAssigned, call: true)
    end

    context "when presence policy is marked as default full time" do
      before do
        allow(presence_policy).to receive(:default_full_time?).and_return(true)
      end
      it "updates presence day and default full time" do
        expect { subject }.to change { PresenceDay.count }.by(1)
        expect(verify_employees_not_assigned_mock).to have_received(:call)
        expect(update_default_full_time_mock).to have_received(:call)
      end
    end

    context "when presence policy is not marked as default full time" do
      it "updates only presence day" do
        expect { subject }.to change { PresenceDay.count }.by(1)
        expect(verify_employees_not_assigned_mock).to have_received(:call)
        expect(update_default_full_time_mock).not_to have_received(:call)
      end
    end
  end
end
