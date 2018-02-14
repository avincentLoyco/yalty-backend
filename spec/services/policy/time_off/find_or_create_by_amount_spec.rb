require "rails_helper"

RSpec.describe Policy::TimeOff::FindOrCreateByAmount do
  subject { described_class.call(time_off_policy_amount, account.id) }

  let(:time_off_policy_amount) { 25 }
  let!(:account) { create(:account) }

  it { expect(subject.amount).to eq(time_off_policy_amount) }
end
