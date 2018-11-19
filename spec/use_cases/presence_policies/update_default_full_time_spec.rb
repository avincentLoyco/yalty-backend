# frozen_string_literal: true

require "rails_helper"

RSpec.describe PresencePolicies::UpdateDefaultFullTime do
  describe "#call" do
    let(:account) { create(:account) }
    let(:old_default_full_time) { account.default_full_time_presence_policy }
    let(:new_default_full_time) { create(:presence_policy, account_id: account.id) }
    let(:old_standard_day_duration) { account.standard_day_duration }
    let(:new_standard_day_duration) { 1500 }

    before do
      allow(new_default_full_time)
        .to receive(:standard_day_duration)
        .and_return(new_standard_day_duration)
    end

    subject { described_class.new.call(presence_policy: new_default_full_time) }

    it "updates account with new default full time presence policy" do
      subject
      account.reload
      expect(account.standard_day_duration).to eq new_standard_day_duration
      expect(account.default_full_time_presence_policy_id).to eq new_default_full_time.id
    end
  end
end
