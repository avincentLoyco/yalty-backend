require 'rails_helper'

RSpec.describe AddBalanceRemovalsJob do
  include_context 'shared_context_account_helper'
  include_context 'shared_context_timecop_helper'

  subject { AddBalanceRemovalsJob.perform_now  }

  let(:employee) { create(:employee) }
  let!(:policy) { create(:time_off_policy, time_off_category: category) }
  let(:category) { create(:time_off_category, account: employee.account) }
  let!(:employee_policy) do
    create(:employee_time_off_policy, employee: employee, time_off_policy: policy)
  end
  let!(:balance) do
    create(:employee_balance,
      employee: employee, effective_at: Date.today - 1.week, validity_date: Date.today,
      time_off_policy: policy, time_off_category: category, amount: 100)
  end

  context 'when employee balance has validity date today' do
    it { expect { subject }.to change { Employee::Balance.count }.by(1) }
    it { expect { subject }.to change { balance.reload.balance_credit_removal } }
    it { expect { subject }.to change { employee.reload.employee_balances.count }.by(1) }

    context 'removal amount' do
      before { subject }

      it { expect(employee.reload.employee_balances.where(policy_credit_removal: true)
        .last.amount).to eq -balance.amount }
    end
  end

  context 'when employee_balance does not have validity date today' do
    before { balance.update!(validity_date: Date.today + 1.week) }

    it { expect { subject }.to_not change { Employee::Balance.count } }
    it { expect { subject }.to_not change { balance.reload.balance_credit_removal } }
    it { expect { subject }.to_not change { employee.reload.employee_balances.count } }
  end
end
