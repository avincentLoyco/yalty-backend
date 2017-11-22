require "rails_helper"

RSpec.describe EmployeePolicy::Presence::OrderOfStartDay::Calculate do
  before { allow(Account).to receive_message_chain(:current, :presence_policies, :find) { presence_policy } }

  subject { described_class.call(presence_policy.id, effective_at) }

  let(:presence_policy) { create(:presence_policy, :with_presence_day) }

  context 'when effective_at is before first presence_day' do
    let(:effective_at) { Time.new(2014, 12, 1) }
    it { expect(subject).to eq(3)}
  end

  context 'when effective_at is after first presence_day' do
    let(:effective_at) { Time.new(2014, 12, 7) }
    it { expect(subject).to eq(3)}
  end

  context 'when effective_at is at first presence_day' do
    let(:effective_at) { Time.new(2014, 12, 3) }
    it { expect(subject).to eq(3)}
  end
end
