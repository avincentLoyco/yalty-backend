# frozen_string_literal: true

require "rails_helper"

RSpec.describe PresenceDays::Destroy do
  describe "#call" do
    subject do
      described_class.new(
        update_default_full_time: update_default_full_time_mock,
        verify_employees_not_assigned: verify_employees_not_assigned_mock,
      )
      .call(
        presence_day: presence_day,
      )
    end

    let(:presence_day) { create(:presence_day) }
    let!(:presence_policy) { presence_day.presence_policy }

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
      it "destroys presence day and updates default full time" do
        expect { subject }.to change { PresenceDay.count }.by(-1)
        expect(verify_employees_not_assigned_mock).to have_received(:call)
        expect(update_default_full_time_mock).to have_received(:call)
      end
    end

    context "when presence policy is not marked as default full time" do
      it "only destroys presence day" do
        expect { subject }.to change { PresenceDay.count }.by(-1)
        expect(verify_employees_not_assigned_mock).to have_received(:call)
        expect(update_default_full_time_mock).not_to have_received(:call)
      end
    end
  end
end
