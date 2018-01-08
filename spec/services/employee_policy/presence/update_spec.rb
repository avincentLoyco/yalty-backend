require "rails_helper"

RSpec.describe EmployeePolicy::Presence::Update do
  before do
    allow(EmployeePolicy::Presence::OrderOfStartDay::Calculate).to receive(:call) { 1 }
    allow(EmployeePolicy::Presence::Balances::Update).to receive(:call) { {} }
    allow(CreateOrUpdateJoinTable).to receive(:call) { join_table_result }
    allow(EmployeePresencePolicy).to receive(:find) { epp_result }
  end

  subject { described_class.call(params) }

  let(:join_table_result)           { { result: employee_presence_policy, status: 201 } }
  let(:epp_result)                  { employee_presence_policy }

  let(:employee_presence_policy)    { build(:employee_presence_policy) }
  let(:employee_presence_policy_id) { employee_presence_policy.id }
  let(:effective_at)                { employee_presence_policy.effective_at + 1.year }

  let(:params) {
    {
      id: employee_presence_policy_id,
      effective_at: effective_at
    }
  }

  it { expect(subject).to eq(join_table_result) }
end
