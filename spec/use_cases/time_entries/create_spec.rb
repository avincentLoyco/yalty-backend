# frozen_string_literal: true

require "rails_helper"

RSpec.describe TimeEntries::Create do
  describe "#call" do
    subject do
      described_class.new(
        update_default_full_time: update_default_full_time_mock,
        verify_employees_not_assigned: verify_employees_not_assigned_mock,
      )
      .call(
        params: params,
        presence_day: presence_day,
      )
    end

    let!(:presence_policy) { create(:presence_policy, :with_presence_day) }
    let(:presence_day) { presence_policy.presence_days.last }
    let(:params) do
      {
        start_time: start_time,
        end_time: end_time,
      }
    end
    let(:start_time) { "8:00" }
    let(:end_time) { "16:00" }

    let(:update_default_full_time_mock) do
      instance_double(PresencePolicies::UpdateDefaultFullTime, call: true)
    end
    let(:verify_employees_not_assigned_mock) do
      instance_double(PresencePolicies::VerifyEmployeesNotAssigned, call: true)
    end

    context "when presence policy is marked as default full time" do
      before do
        allow(PresenceDay).to receive(:find).with(presence_day.id).and_return(presence_day)
        allow(presence_day.presence_policy).to receive(:default_full_time?).and_return(true)
      end
      it "creates time entry and updates default full time" do
        expect { subject }.to change { TimeEntry.count }.by(1)
        expect(verify_employees_not_assigned_mock).to have_received(:call)
        expect(update_default_full_time_mock).to have_received(:call)
      end
    end

    context "when presence policy is not marked as default full time" do
      it "only creates time entry" do
        expect { subject }.to change { TimeEntry.count }.by(1)
        expect(verify_employees_not_assigned_mock).to have_received(:call)
        expect(update_default_full_time_mock).not_to have_received(:call)
      end
    end
  end
end
