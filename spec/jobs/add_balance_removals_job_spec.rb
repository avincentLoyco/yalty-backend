require 'rails_helper'

RSpec.describe AddBalanceRemovalsJob do
  include_context 'shared_context_account_helper'
  include_context 'shared_context_timecop_helper'

  subject { AddBalanceRemovalsJob.perform_now  }

  let(:employee) { create(:employee) }
  let!(:policy) do
    create(:time_off_policy,
      time_off_category: category,
      start_day: 1,
      start_month: 12,
      end_month: Date.today.month,
      end_day: Date.today.day,
      years_to_effect: 1
    )

  end
  let(:category) { create(:time_off_category, account: employee.account) }
  let!(:employee_policy) do
    create(:employee_time_off_policy, employee: employee, time_off_policy: policy)
  end
  let!(:balance) do
    create(:employee_balance,
      employee: employee, effective_at: Date.today - 1.month, validity_date: Date.today,
      time_off_category: category, resource_amount: 100)
  end

  context 'when employee balance has validity date today' do
    context 'and these is only balance with validity date today' do
      it { expect { subject }.to change { Employee::Balance.count }.by(1) }
      it { expect { subject }.to change { balance.reload.balance_credit_removal } }
      it { expect { subject }.to change { employee.reload.employee_balances.count }.by(1) }

      it '' do
        subject
        removal_balance = employee.reload.employee_balances.find_by(effective_at: Date.today)
        expect(removal_balance.validity_date ).to eq (Date.today )
      end

      context 'and balance credit addition is not policy addition' do
        before { subject }

        it { expect(balance.reload.balance_credit_removal.amount).to eq -balance.amount }
      end
    end

    context 'and there are other balances with validity dates today' do
      context 'and they are in the same time off category' do
        let!(:same_day_balance) do
          create(:employee_balance_manual, :with_time_off,
            employee: balance.employee, time_off_category: balance.time_off_category,
            effective_at: balance.effective_at + 1.month, validity_date: balance.validity_date)
        end

        it { expect { subject }.to change { Employee::Balance.removals.uniq.count }.by(1) }
        it { expect { subject }.to change { balance.reload.balance_credit_removal_id } }
        it { expect { subject }.to change { same_day_balance.reload.balance_credit_removal_id } }

        it 'has valid additions assigned' do
          subject
          removal_balance = employee.reload.employee_balances.find_by(effective_at: Date.today)
          expect(removal_balance.balance_credit_additions.pluck(:id))
            .to contain_exactly(balance.id, same_day_balance.id)
        end

        it 'has valid amount' do
          subject
          removal_balance = employee.reload.employee_balances.find_by(effective_at: Date.today)
          expect(removal_balance.resource_amount).to eq -balance.amount
        end
      end

      context 'and they are in different time off category' do
        let(:new_category) { create(:time_off_category, account: employee.account) }
        let!(:same_day_balance) do
          create(:employee_balance,
            employee: balance.employee, time_off_category: new_category,
            effective_at: balance.effective_at + 1.month, validity_date: balance.validity_date)
        end

        it { expect { subject }.to change { Employee::Balance.removals.uniq.count }.by(2) }

        it 'additions have different removals assigned' do
          subject

          expect(same_day_balance.reload.balance_credit_removal_id)
            .to_not eq(balance.reload.balance_credit_removal_id)
        end
      end
    end
  end

  context 'when employee balance already has removals' do
    before { subject }

    it { expect { subject }.to_not change { Employee::Balance.count } }
    it { expect { subject }.to_not change { balance.reload.balance_credit_removal } }
  end

  context 'when employee_balance does not have validity date today' do
    before { balance.update!(validity_date: Date.today + 1.week) }

    it { expect { subject }.to_not change { Employee::Balance.count } }
    it { expect { subject }.to_not change { balance.reload.balance_credit_removal } }
    it { expect { subject }.to_not change { employee.reload.employee_balances.count } }
  end
end
