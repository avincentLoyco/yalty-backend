# frozen_string_literal: true

require "rails_helper"

RSpec.describe PresencePolicies::Create do
  describe "#call" do
    subject do
      described_class.new(
        update_default_full_time: update_default_full_time_mock,
        create_presence_days: create_presence_days_mock,
      ).call(
        account: account,
        params: params,
        days_params: days_params,
        default_full_time: default_full_time
      )
    end

    let!(:account) { create(:account) }
    let(:params) do
      {
        name: "name",
        occupation_rate: 1.0,
      }
    end
    let(:days_params) { [] }
    let(:default_full_time) { false }

    let(:update_default_full_time_mock) do
      instance_double(PresencePolicies::UpdateDefaultFullTime, call: true)
    end

    let(:create_presence_days_mock) do
      instance_double(PresencePolicies::CreatePresenceDays, call: true)
    end

    context "when data is valid" do
      context "when default_full_time is false" do
        it "creates new presence policy with presence days" do
          expect { subject }.to change { PresencePolicy.count }.by(1)
          expect(create_presence_days_mock).to have_received(:call)
          expect(update_default_full_time_mock).to_not have_received(:call)
        end
      end

      context "when default_full_time is true" do
        let(:default_full_time) { true }

        before { subject }

        it "updates the account with new default presence policy" do
          expect(update_default_full_time_mock).to have_received(:call)
        end
      end
    end

    context "when exception occurs" do
      let(:presence_policies_count) { account.presence_policies.count }

      context "while saving presence policy" do
        let(:params) { {} }

        it "doesn't create the policy and doesn't update the account" do
          expect { subject }.to raise_error ActiveRecord::RecordInvalid
          expect(account.reload.presence_policies.count).to eq presence_policies_count
        end
      end

      context "while creating present days" do
        before do
          allow(create_presence_days_mock)
            .to receive(:call).and_raise(ActiveRecord::RecordInvalid.new(PresencePolicy.new))
        end

        it "doesn't create the policy and doesn't update the account" do
          expect { subject }.to raise_error ActiveRecord::RecordInvalid
          expect(account.reload.presence_policies.count).to eq presence_policies_count
        end
      end

      context "while updating the account" do
        let(:default_full_time) { true }

        before do
          allow(update_default_full_time_mock)
            .to receive(:call).and_raise(ActiveRecord::RecordInvalid.new(PresencePolicy.new))
        end

        it "doesn't create the policy and doesn't update the account" do
          expect { subject }.to raise_error ActiveRecord::RecordInvalid
          account.reload
          expect(account.presence_policies.count).to eq presence_policies_count
        end
      end
    end
  end
end
