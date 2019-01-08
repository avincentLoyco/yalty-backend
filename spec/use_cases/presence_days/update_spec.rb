# frozen_string_literal: true

require "rails_helper"

RSpec.describe PresenceDays::Update do
  describe "#call" do
    subject do
      described_class.new(
        update_default_full_time: update_default_full_time_mock,
        verify_employees_not_assigned: verify_employees_not_assigned_mock,
      )
      .call(
        presence_day: presence_day,
        params: params,
      )
    end

    let(:presence_day) { create(:presence_day) }
    let(:presence_policy) { presence_day.presence_policy }
    let(:params) { {} }

    let(:update_default_full_time_mock) do
      instance_double(PresencePolicies::UpdateDefaultFullTime, call: true)
    end
    let(:verify_employees_not_assigned_mock) do
      instance_double(PresencePolicies::VerifyEmployeesNotAssigned, call: true)
    end

    before do
      allow(presence_day).to receive(:update!)
    end

    context "when presence policy is marked as default full time" do
      before do
        allow(presence_policy).to receive(:default_full_time?).and_return(true)
      end
      it "updates presence day and default full time" do
        subject
        expect(verify_employees_not_assigned_mock).to have_received(:call)
        expect(update_default_full_time_mock).to have_received(:call)
        expect(presence_day).to have_received(:update!)
      end
    end

    context "when presence policy is not marked as default full time" do
      it "updates only presence day" do
        subject
        expect(verify_employees_not_assigned_mock).to have_received(:call)
        expect(update_default_full_time_mock).not_to have_received(:call)
        expect(presence_day).to have_received(:update!)
      end
    end
  end
end
