require "rails_helper"

RSpec.describe Policy::TimeOff::FindOrCreateByAmount do
  before do
    allow(Policy::TimeOff::FindByAmount).to receive(:call)   {}
    allow(Policy::TimeOff::CreateByAmount).to receive(:call) { time_off_policy }
  end

  subject { described_class.call(time_off_policy_amount, account.id) }

  let(:time_off_policy_amount) { 25 }
  let!(:account) { create(:account) }
  let!(:time_off_policy) do
    create(:time_off_policy,
      amount: 25,
      active: true,
      time_off_category_id: time_off_category.id)
  end
  let!(:time_off_category) { account.time_off_categories.find_by(name: 'vacation') }

  it { expect(subject.amount).to eq(time_off_policy_amount) }
end
