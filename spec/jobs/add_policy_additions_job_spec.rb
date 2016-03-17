require 'rails_helper'

RSpec.describe AddPolicyAdditionsJob do
  include_context 'shared_context_account_helper'
  include_context 'shared_context_timecop_helper'

  subject { AddPolicyAdditionsJob.perform_now }

  let(:account) { create(:account) }
  let(:category) { create(:time_off_category, account: account) }
  let(:policy) { create(:time_off_policy, time_off_category: category) }
  let(:working_place) { create(:working_place, account: account) }
  let!(:employees) { create_list(:employee, 2, account: account, working_place: working_place) }
  let(:employee_balance) { create(:employee_balance, employee: employees.first) }
  let!(:working_place_policy) do
    create(:working_place_time_off_policy,
      time_off_policy: policy, working_place: working_place, effective_at: Date.today
    )
  end

  describe '#perform' do
    let!(:employee_balance) do
      create(:employee_balance, employee: employees.first, time_off_category: category,
        time_off_policy: policy, amount: -100, effective_at: Time.now + 1.week)
    end

    context 'when policy starts today' do
      context 'when policy type is counter' do
        before { policy.update!(policy_type: 'counter', amount: nil) }

        it { expect { subject }.to change { Employee::Balance.count }.by(2) }
        it { expect { subject }.to change { policy.reload.employee_balances.count }.by(2) }
        it { expect { subject }.to change { employees.first.reload.employee_balances.count }.by(1) }
        it { expect { subject }.to change { employees.last.reload.employee_balances.count }.by(1) }
        it { expect { subject }.to change { employee_balance.reload.being_processed } }

        context 'and already called' do
          before { subject }

          it { expect { subject }.to_not change { Employee::Balance.count } }
          it { expect { subject }.to_not change { policy.reload.employee_balances.count } }
          it { expect { subject }.to_not change { employees.first.reload.employee_balances.count } }
          it { expect { subject }.to_not change { employees.last.reload.employee_balances.count } }
          it { expect { subject }.to_not change { employee_balance.reload.being_processed } }
        end
      end

      context 'when policy type is balancer' do
        it { expect { subject }.to change { Employee::Balance.count }.by(2) }
        it { expect { subject }.to change { policy.reload.employee_balances.count }.by(2) }
        it { expect { subject }.to change { employees.first.reload.employee_balances.count }.by(1) }
        it { expect { subject }.to change { employees.last.reload.employee_balances.count }.by(1) }
        it { expect { subject }.to change { employee_balance.reload.being_processed } }

        context 'and already called' do
          before { subject }

          it { expect { subject }.to_not change { Employee::Balance.count } }
          it { expect { subject }.to_not change { policy.reload.employee_balances.count } }
          it { expect { subject }.to_not change { employees.first.reload.employee_balances.count } }
          it { expect { subject }.to_not change { employees.last.reload.employee_balances.count } }
          it { expect { subject }.to_not change { employee_balance.reload.being_processed } }
        end
      end

      context 'when two employee policies starts at the same day' do
        let(:new_policy) { create(:time_off_policy, time_off_category: category) }
        let!(:second_working_place_policy) do
          create(:working_place_time_off_policy,
            time_off_policy: new_policy, working_place: working_place,
            effective_at: Date.today + 8.hours
          )
        end

        it { expect { subject }.to change { Employee::Balance.count }.by(2) }
        it { expect { subject }.to change { new_policy.reload.employee_balances.count }.by(2) }

        it { expect { subject }.to_not change { policy.reload.employee_balances } }
      end
    end

    context 'when policy do not starts today' do
      before { policy.update!(start_day: 10) }

      it { expect { subject }.to_not change { Employee::Balance.count } }
      it { expect { subject }.to_not change { policy.reload.employee_balances.count } }
      it { expect { subject }.to_not change { employee_balance.reload.being_processed } }
    end
  end
end
