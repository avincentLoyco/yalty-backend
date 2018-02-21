require "rails_helper"

RSpec.describe EmployeePolicy::Presence::Balances::Update do

  before { allow(FindAndUpdateEmployeeBalancesForJoinTables).to receive(:call) { {} } }

  subject { described_class.call(employee_presence_policy, attributes, previous_effective_at) }

  let(:employee_presence_policy)    { build(:employee_presence_policy) }
  let(:effective_at)                { employee_presence_policy.effective_at }
  let(:order_of_start_day)          { 1 }
  let(:previous_effective_at)       { }
  let(:previous_order_of_start_day) { }

  context "when Employee Presence Policy was created" do
    let(:attributes) {
      {
        id: employee_presence_policy.id,
        effective_at: effective_at,
        order_of_start_day: order_of_start_day
      }
    }

    it { expect(subject).to eq( {} ) }
  end

  context "when Employee Presence Policy was updated" do
    let(:attributes) {
      {
        id: employee_presence_policy.id,
        effective_at: effective_at,
        order_of_start_day: order_of_start_day,
        previous_order_of_start_day: previous_order_of_start_day
      }
    }

    context "when effective_at and order_of_start day changed" do
      let(:previous_effective_at)       { effective_at - 1.month }
      let(:previous_order_of_start_day) { order_of_start_day + 2 }

      it { expect(subject).to eq( {} ) }
    end

    context "when effective_at and order_of_start day did not changed" do
      let(:previous_effective_at)       { effective_at }
      let(:previous_order_of_start_day) { order_of_start_day }

      it { expect(subject).to eq(nil) }
    end
  end
end
