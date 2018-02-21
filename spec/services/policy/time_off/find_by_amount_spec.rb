require "rails_helper"

RSpec.describe Policy::TimeOff::FindByAmount do
  before do
    allow(Account).to receive(:find) { account }
  end

  subject { described_class.call(time_off_policy_amount, account.id) }

  let(:time_off_policy_amount) { 25 }
  let!(:account) { create(:account) }
  let!(:time_off_category) { account.time_off_categories.find_by(name: "vacation") }
  let!(:time_off_policy) do
    create(:time_off_policy,
      amount: 25,
      active: true,
      time_off_category_id: time_off_category.id)
  end

  context "when time off policy with provided amount exists" do
    it { expect(subject).to eq(time_off_policy) }
  end

  context "when time off policy with provided amount does not exist" do
    let(:time_off_policy_amount) { 23 }
    it { expect(subject).to eq(nil) }
  end
end
