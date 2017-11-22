require "rails_helper"

RSpec.describe EmployeePolicy::Presence::Destroy do
  before do
    allow(ClearResetJoinTables).to receive(:call) { }
    allow(FindAndUpdateEmployeeBalancesForJoinTables).to receive(:call) { }
  end

  subject { described_class.call(employee_presence_policy) }

  let!(:employee_presence_policy) { create(:employee_presence_policy) }
  let(:employee)                  { employee_presence_policy.employee }

  it { expect { subject }.to change { employee.employee_presence_policies.not_reset.count }.by(-1) }
end
