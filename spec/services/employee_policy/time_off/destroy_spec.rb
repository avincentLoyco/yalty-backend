require "rails_helper"

RSpec.describe EmployeePolicy::TimeOff::Destroy do
  before do
    allow(ClearResetJoinTables).to receive(:call) { }
    allow(RecreateBalances::AfterEmployeeTimeOffPolicyDestroy).to receive(:call) { }
  end

  subject { described_class.call(employee_time_off_policy) }

  let!(:employee_time_off_policy) { create(:employee_time_off_policy) }
  let(:employee)                  { employee_time_off_policy.employee }

  it { expect { subject }.to change { employee.employee_time_off_policies.not_reset.count }.by(-1) }
end
