# frozen_string_literal: true

require "rails_helper"

RSpec.describe TimeEntries::Destroy do
  describe "#call" do
    subject do
      described_class.new(
        update_default_full_time: update_default_full_time_mock,
        verify_employees_not_assigned: verify_employees_not_assigned_mock,
      )
      .call(
        time_entry: time_entry,
      )
    end

    let(:time_entry) { create(:time_entry) }
    let!(:presence_policy) { time_entry.presence_day.presence_policy }

    let(:update_default_full_time_mock) do
      instance_double(PresencePolicies::UpdateDefaultFullTime, call: true)
    end
    let(:verify_employees_not_assigned_mock) do
      instance_double(PresencePolicies::VerifyEmployeesNotAssigned, call: true)
    end

    before do
      allow(time_entry.presence_day).to receive(:update_minutes!)
    end

    context "when presence policy is marked as default full time" do
      before do
        allow(presence_policy).to receive(:default_full_time?).and_return(true)
      end
      it "destroys time entry and updates default full time" do
        expect { subject }.to change { TimeEntry.count }.by(-1)
        expect(time_entry.presence_day).to have_received(:update_minutes!)
        expect(verify_employees_not_assigned_mock).to have_received(:call)
        expect(update_default_full_time_mock).to have_received(:call)
      end
    end

    context "when presence policy is not marked as default full time" do
      it "only destroys time entry" do
        expect { subject }.to change { TimeEntry.count }.by(-1)
        expect(time_entry.presence_day).to have_received(:update_minutes!)
        expect(verify_employees_not_assigned_mock).to have_received(:call)
        expect(update_default_full_time_mock).not_to have_received(:call)
      end
    end
  end
end
