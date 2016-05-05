require 'rails_helper'

RSpec.describe ManageEmployeeBalanceRemoval, type: :service do
  include_context 'shared_context_account_helper'

  let!(:balance) do
    create(:employee_balance, effective_at: Date.today - 2.years, validity_date: validity_date)
  end

  describe '#call' do
    subject { ManageEmployeeBalanceRemoval.new(new_date, balance).call }

    let(:validity_date) { Date.today - 1.day }
    let(:new_date) { Date.today }

    context 'when employee balance is a balancer' do
      context 'when validity date present' do
        context 'and in past' do
          let!(:removal) { create(:employee_balance, balance_credit_addition: balance) }

          context 'and moved to future' do
            let(:new_date) { Date.today + 1.week }

            it { expect { subject }.to change { Employee::Balance.count }.by(-1) }
          end

          context 'and moved to past' do
            let(:new_date) { Date.today - 2.weeks }

            it { expect { subject }.to_not change { Employee::Balance.count } }
          end

          context 'and now not present' do
            let(:new_date) { nil }

            it { expect { subject }.to change { Employee::Balance.count }.by(-1) }
          end
        end

        context 'and in future' do
          let(:validity_date) { Date.today + 1.week }

          context 'and moved to today or earlier' do
            it { expect { subject }.to change { Employee::Balance.count }.by(1) }
          end

          context 'and moved to future' do
            let(:new_date) { Date.today + 1.month }

            it { expect { subject }.to_not change { Employee::Balance.count } }
          end

          context 'and now not present' do
            let(:new_date) { nil }

            it { expect { subject }.to_not change { Employee::Balance.count } }
          end
        end
      end

      context 'when validity date not present' do
        let(:validity_date) { nil }

        context 'and now in future' do
          let(:new_date) { Date.today + 1.week }

          it { expect { subject }.to_not change { Employee::Balance.count } }
        end

        context 'and now in past' do
          it { expect { subject }.to change { Employee::Balance.count }.by(1) }
        end
      end
    end

    context 'when employee balance is a counter' do
      before { balance.time_off_policy.update!(policy_type: 'counter', amount: nil) }

      it { expect { subject }.to_not change { Employee::Balance.count } }
    end
  end
end
