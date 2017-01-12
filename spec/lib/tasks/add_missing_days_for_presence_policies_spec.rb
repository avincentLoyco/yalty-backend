require 'rails_helper'
require 'rake'

RSpec.describe 'add_missing_days_to_presence_policies:update_policies', type: :rake do
  include_context 'shared_context_account_helper'
  include_context 'rake'

  let!(:account) { create(:account) }
  let!(:policy) { create(:presence_policy, :with_time_entries, number_of_days: 7, account: account) }

  subject { rake['add_missing_days_to_presence_policies:update_policies'].invoke }

  context 'when policy has different number of days than 7' do
    let!(:employee) { create(:employee, account: account) }
    let!(:employee_balance) { create(:employee_balance, employee: employee) }
    let!(:epp) do
      create(:employee_presence_policy,
        employee: employee, effective_at: employee.hired_date, presence_policy: policy)
    end

    before do
      policy.presence_days.where(order: order).destroy_all
      policy.reload.presence_days
    end

    context 'when middle day is added' do
      let(:order) { 4 }

      it { expect { subject }.to change { policy.reload.presence_days.count }.by(1) }
      it { expect { subject }.to_not change { employee_balance.reload.being_processed } }
    end

    context 'when last day is added' do
      let(:order) { 7 }

      it { expect { subject }.to change { policy.reload.presence_days.count }.by(1) }
      it { expect { subject }.to change { employee_balance.reload.being_processed }.to true }
    end
  end

  context 'when policy has 7 presence days assigned' do
    it { expect { subject }.to_not change { policy.reload.presence_days.count } }
  end
end
