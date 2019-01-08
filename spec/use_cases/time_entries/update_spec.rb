# frozen_string_literal: true

require "rails_helper"

RSpec.describe TimeEntries::Update do
  describe "#call" do
    subject do
      described_class.new(
        update_default_full_time: update_default_full_time_mock,
        verify_employees_not_assigned: verify_employees_not_assigned_mock,
      )
      .call(
        time_entry: time_entry,
        params: params,
      )
    end

    let(:time_entry) { create(:time_entry) }
    let!(:presence_policy) { time_entry.presence_day.presence_policy }
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

    before do
      allow(time_entry).to receive(:update!)
    end

    context "when presence policy is marked as default full time" do
      before do
        allow(presence_policy).to receive(:default_full_time?).and_return(true)
      end
      it "updates time entry and updates default full time" do
        subject
        expect(time_entry).to have_received(:update!).with(params)
        expect(verify_employees_not_assigned_mock).to have_received(:call)
        expect(update_default_full_time_mock).to have_received(:call)
      end
    end

    context "when presence policy is not marked as default full time" do
      it "only creates time entry" do
        subject
        expect(time_entry).to have_received(:update!).with(params)
        expect(verify_employees_not_assigned_mock).to have_received(:call)
        expect(update_default_full_time_mock).not_to have_received(:call)
      end
    end
  end
end
