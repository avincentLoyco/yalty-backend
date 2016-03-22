require 'rails_helper'

RSpec.describe ManageEmployeeBalances, type: :service do
  include_context 'shared_context_timecop_helper'
  include_context 'shared_context_account_helper'

  describe '#call' do
    subject { ManageEmployeeBalances.new(current_employee_policy).call }
    before do
      previous_employee_policy.time_off_policy.update!(
        time_off_category: current_employee_policy.time_off_policy.time_off_category
      )
    end
    let(:employee) { create(:employee) }
    let(:previous_balance) { previous_employee_policy.time_off_policy.employee_balances.first }
    let!(:previous_employee_policy) do
      create(:employee_time_off_policy, :with_employee_balance,
        employee: employee, effective_at: Time.now - 2.years
      )
    end
    let!(:current_employee_policy) do
      create(:employee_time_off_policy, :with_employee_balance,
        employee: employee, effective_at: effective_at
      )
    end

    context 'when current policy effective at is in future' do
      let(:effective_at) { Time.now + 1.month }

      it { expect { subject }.to_not change { Employee::Balance.count } }
      it { expect { subject }.to_not change { previous_balance.reload.being_processed } }
    end

    context 'when current policy effective at is in past' do
      context 'and its start date is eql previous policy start date' do
        let(:effective_at) { previous_employee_policy.time_off_policy.start_date }

        it { expect { subject }.to_not change { Employee::Balance.count } }
        it { expect { subject }.to change { previous_balance.reload.being_processed } }
      end

      context 'and its start date is after previous policy start date' do
        let(:effective_at) { Time.now - 2.months }

        it { expect { subject }.to change { Employee::Balance.count }.by(1) }
        it { expect { subject }.to_not change { previous_balance.reload.being_processed } }
      end
    end
  end
end
