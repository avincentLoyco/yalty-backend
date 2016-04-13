require 'rails_helper'

RSpec.describe ManageEmployeeBalances, type: :service do
  include_context 'shared_context_timecop_helper'
  include_context 'shared_context_account_helper'

  describe '#call' do
    subject { ManageEmployeeBalances.new(current_employee_policy).call }
    let(:account) { create(:account) }
    let(:employee) { create(:employee, account: account) }
    let(:category) { create(:time_off_category, account: account) }
    let(:previous_balance) { Employee::Balance.last }
    let(:old_policy) { create(:time_off_policy, time_off_category_id: category.id) }
    let(:new_policy) { create(:time_off_policy, time_off_category_id: category.id, amount: 100) }
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

      context 'and previous policy start date is today' do
        it { expect { subject }.to_not change { Employee::Balance.count } }
        it { expect { subject }.to change { previous_balance.reload.being_processed } }
      end

      context 'and previous policy start date is not today' do
        before do
          old_policy.update!(start_month: 12)
          previous_balance.update!(effective_at: previous_employee_policy.last_start_date)
        end

        it { expect { subject }.to change { Employee::Balance.count }.by(1) }
        it { expect { subject }.to_not change  { previous_balance.reload.being_processed } }
      end
    end

    context 'when current policy effective at is in past' do
      context 'and has validity in past' do
        let(:effective_at) { Time.now - 1.year + 1.day }
        before do
          new_policy.update!(start_day: 3, end_day: 4, end_month: 1, years_to_effect: 0)
        end

        it { expect { subject }.to change {
          Employee::Balance.where(policy_credit_removal: true).count }.by(1) }
      end

      context 'validity date not present or in future' do
        let(:effective_at) { Time.now - 1.year }
        before do
          Employee::Balance.first.update!(
          effective_at: previous_employee_policy.previous_start_date + 1.month)
        end

        context 'and its start date is eql previous policy start date' do
          it { expect { subject }.to_not change { Employee::Balance.count } }
          it { expect { subject }.to change { previous_balance.reload.being_processed } }

          context 'and previous addition has its removal' do
            let!(:removal) do
              create(:employee_balance,
                effective_at: previous_balance.validity_date,
                balance_credit_addition: previous_balance,
                policy_credit_removal: true,
                employee: previous_balance.employee,
                time_off_category: previous_balance.time_off_category
              )
            end

            it { expect { subject }.to change { previous_balance.reload.being_processed } }
            it { expect { subject }.to change { Employee::Balance.exists?(id: removal.id) } }
          end

          context 'and current addition has end date before current date' do
            before { new_policy.update!(end_day: 2, end_month: 12) }

            it { expect { subject }.to change { previous_balance.reload.being_processed } }
          end
        end

        context 'and its start date is before previous policy start date' do
          before { old_policy.update!(start_day: 4) }

          it { expect { subject }.to change { Employee::Balance.exists?(id: previous_balance.id) } }

          context 'and it has existing removal' do
            let!(:removal) do
              create(:employee_balance,
                effective_at: previous_balance.validity_date,
                balance_credit_addition: previous_balance,
                policy_credit_removal: true,
                employee: previous_balance.employee,
                time_off_category: previous_balance.time_off_category
              )
            end
            before do
              old_policy.update!(end_month: 12, end_day: 31)
              previous_balance.update!(validity_date: '31/12/2015')
            end

            it { expect { subject }.to change { Employee::Balance.exists?(id: removal.id) } }
            it { expect { subject }.to change { Employee::Balance.exists?(id: previous_balance.id) } }
          end
        end
      end
    end
  end
end
