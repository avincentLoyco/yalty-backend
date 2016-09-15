require 'rails_helper'

RSpec.describe AddPolicyAdditionsJob do
  include_context 'shared_context_account_helper'
  include_context 'shared_context_timecop_helper'

  subject { AddPolicyAdditionsJob.perform_now }

  let(:account) { create(:account) }
  let(:category) { create(:time_off_category, account: account) }
  let(:policy) { create(:time_off_policy, time_off_category: category, years_to_effect: 3) }
  let!(:employees) { create_list(:employee, 3, account: account) }
  let!(:employee_time_off_policies) do
    [employees.first, employees.second, employees.last].map do |employee|
      create(:employee_time_off_policy,
        time_off_policy: policy, employee: employee, effective_at: Date.today
      )
    end
  end

  describe '#perform' do
    let(:first_employees_balances) { employees.first.reload.employee_balances }
    let(:second_employees_balances) { employees.second.reload.employee_balances }
    let(:last_employees_balances ) { employees.last.reload.employee_balances }
    let(:employee_balance) do
      create(:employee_balance_manual, :with_time_off,
        employee: employees.first,
        time_off_category: category,
        resource_amount: -100,
        effective_at: 1.week.from_now
      )
    end

    shared_examples 'Already called policy' do
      it { expect { subject }.to_not change { Employee::Balance.count } }
      it { expect { subject }.to_not change { category.reload.employee_balances.count } }
      it { expect { subject }.to_not change { first_employees_balances.count } }
      it { expect { subject }.to_not change { last_employees_balances.count } }
      it { expect { subject }.to_not change { employee_balance.reload.being_processed } }
    end

    shared_examples 'Policy called for a first time' do
      it { expect { subject }.to change { Employee::Balance.count }.by(3) }
      it { expect { subject }.to change { category.reload.employee_balances.count }.by(3) }
      it { expect { subject }.to change { first_employees_balances.count }.by(1) }
      it { expect { subject }.to change { last_employees_balances.count }.by(1) }
      it { expect { subject }.to change { employee_balance.reload.being_processed } }
    end

    context 'when policy starts today' do
      context 'when policy type is counter' do
        before { policy.update!(policy_type: 'counter', amount: nil) }

        it_behaves_like 'Policy called for a first time'

        context 'and already called' do
          before { subject }

          it_behaves_like 'Already called policy'
        end
      end

      context 'when policy type is balancer' do
        it_behaves_like 'Policy called for a first time'

        context 'and already called' do
          before { subject }

          it_behaves_like 'Already called policy'
        end

        context 'and its years_to_effect eq 3' do
          context 'and policy has end date' do
            before { policy.update!(end_month: 4, end_day: 1) }

            it 'balance should have validity date eq 1/4/2019' do
              subject

              expect(second_employees_balances.first.validity_date.to_date)
                .to eq '1/4/2019'.to_date
            end
          end

          context 'and this is not start date' do
            before { employee_time_off_policies.first.update!(effective_at: Date.today - 1.year) }

            it { expect { subject }.to change { Employee::Balance.count }.by(2) }
            it { expect { subject }.to change { category.reload.employee_balances.count }.by(2) }
            it { expect { subject }.to change { second_employees_balances.count }.by(1) }
            it { expect { subject }.to change { last_employees_balances.count }.by(1) }
            it { expect { subject }.to_not change { employee_balance.reload.being_processed } }
            it { expect { subject }.to_not change { first_employees_balances.count } }
          end
        end
      end
    end

    context 'when policy do not starts today' do
      before { policy.update!(start_day: 10) }

      it { expect { subject }.to_not change { Employee::Balance.count } }
      it { expect { subject }.to_not change { category.reload.employee_balances.count } }
      it { expect { subject }.to_not change { employee_balance.reload.being_processed } }
    end
  end
end
