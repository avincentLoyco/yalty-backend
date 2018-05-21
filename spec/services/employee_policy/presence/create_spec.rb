require "rails_helper"

RSpec.describe EmployeePolicy::Presence::Create do
  before do
    allow(CreateOrUpdateJoinTable).to receive(:call) { response_from_create_or_update_join_table_service }
    allow(EmployeePolicy::Presence::Balances::Update).to receive(:call) { {} }
    allow(Employee::Event).to receive(:find) { event }
    allow(EmployeePolicy::Presence::OrderOfStartDay::Calculate).to receive(:call) { 1 }
  end

  subject { described_class.call(params) }

  let(:event_type) { "hired" }
  let(:effective_at) { Date.new(2017, 2, 1) }

  let(:event) { build(:employee_event, effective_at: effective_at) }
  let(:employee_presence_policy) { build(:employee_presence_policy, effective_at: effective_at, employee_event_id: event.id) }

  let(:params) do
    {
      event_id: event.id,
      presence_policy_id: employee_presence_policy.presence_policy.id,
    }
  end

  let(:response_from_create_or_update_join_table_service) do
    {
      result: employee_presence_policy,
      status: 201,
    }
  end

  it { expect(subject).to eq(response_from_create_or_update_join_table_service) }
end
