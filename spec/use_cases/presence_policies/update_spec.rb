# frozen_string_literal: true

require "rails_helper"

RSpec.describe PresencePolicies::Update do
  describe "#call" do
    subject do
      described_class.new.call(
        presence_policy: presence_policy,
        params: params,
        default_full_time: default_full_time
      )
    end

    let_it_be(:account) { create(:account) }
    let(:presence_policy) { create(:presence_policy, account_id: account.id, occupation_rate: 1.0) }
    let(:standard_day_duration) { 123 }
    let(:default_full_time) { false }
    let(:params) { { occupation_rate: 0.8 } }

    context "when data is valid" do
      before do
        allow(presence_policy)
          .to receive(:standard_day_duration)
          .and_return(standard_day_duration)
      end

      it "updates presence policy with given params" do
        expect { subject }.to change { presence_policy.occupation_rate }.from(1.0).to(0.8)
      end

      context "when default_full_time is true" do
        let(:default_full_time) { true }

        before do
          subject
          account.reload
        end

        it "updates the account with new default full time presence policy" do
          expect(account.default_full_time_presence_policy_id).to eq presence_policy.id
          expect(account.standard_day_duration).to eq presence_policy.standard_day_duration
        end
      end
    end

    context "when exception occures" do
      context "while saving presence policy" do
        before do
          allow(presence_policy)
            .to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(presence_policy))
        end

        it "doesn't update the policy" do
          expect { subject }.to raise_error ActiveRecord::RecordInvalid
          expect(presence_policy.reload.occupation_rate).to eq 1.0
        end
      end

      context "while updating the account" do
        let(:default_full_time) { true }
        before do
          allow(presence_policy.account)
            .to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(account))
        end

        it "doesn't update the policy and doesn't update the account" do
          expect { subject }.to raise_error ActiveRecord::RecordInvalid
          expect(presence_policy.reload.occupation_rate).to eq 1.0
          expect(account.reload.default_full_time_presence_policy_id).not_to eq(presence_policy.id)
        end
      end
    end
  end
end
