require 'rails_helper'

RSpec.describe ManageEmployeeBalances, type: :service do
  include_context 'shared_context_timecop_helper'
  include_context 'shared_context_account_helper'

  describe '#call' do
    subject { ManageEmployeeBalances.new(current_employee_policy).call }
    let(:account) { create(:account) }
    let(:employee) { create(:employee, account: account) }
    let(:category) { create(:time_off_category, account: account) }
    let(:previous_balance) { previous_employee_policy.time_off_policy.employee_balances.first }
    let(:old_policy) { create(:time_off_policy, time_off_category_id: category.id) }
    let(:new_policy) { create(:time_off_policy, time_off_category_id: category.id) }
    let!(:previous_employee_policy) do
      create(:employee_time_off_policy, :with_employee_balance,
        employee: employee, effective_at: Time.now - 2.years, time_off_policy: old_policy
      )
    end
    let!(:current_employee_policy) do
      create(:employee_time_off_policy,
        employee: employee, effective_at: effective_at, time_off_policy: new_policy
      )
    end

    context 'when current policy effective at is in future' do
      let(:effective_at) { Time.now + 20.months }

      it { expect { subject }.to_not change { Employee::Balance.count } }
      it { expect { subject }.to_not change { previous_balance.reload.being_processed } }
    end

    context 'when current policy effective at today' do
      let(:effective_at) { Time.now }

      it { expect { subject }.to change {
        current_employee_policy.reload.employee.employee_balances.count }.by(1) }
      it { expect { subject }.to change { previous_balance.destroyed? } }
    end

    context 'when current policy effective at is in past' do
      let(:effective_at) { Time.now - 1.year }
      before do
        Employee::Balance.first.update!(effective_at: previous_employee_policy.previous_start_date)
      end

      context 'and its start date is eql previous policy start date' do
        it { expect { subject }.to_not change { Employee::Balance.count } }
        it { expect { subject }.to change { previous_balance.reload.being_processed } }
      end

      context 'and its start date is after previous policy start date' do
        before { new_policy.update!(start_day: 4) }

        it { expect { subject }.to change { Employee::Balance.count }.by(1) }
        it { expect { subject }.to_not change { previous_balance.reload.being_processed } }
      end
    end
  end
end
