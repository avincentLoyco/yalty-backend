require 'rails_helper'

RSpec.describe UpdateBalanceJob do
  include_context 'shared_context_account_helper'
  include_context 'shared_context_timecop_helper'

  subject { UpdateBalanceJob.perform_now(balance_id, options) }
  let(:account) { create(:account) }
  let(:employee) { create(:employee, account: account) }
  let(:options) { {} }

  context 'for employee balance which policy is a counter' do
    include_context 'shared_context_balances',
      type: 'counter',
      years_to_effect: 0

    before { Employee::Balance.update_all(being_processed: true) }

    context 'and balance from previous policy period is edited' do
      let(:balance_id) { previous_balance.id }
      let(:options) { { amount: -100 } }

      it { expect { subject }.to change { previous_balance.reload.amount }.to(-100) }
      it { expect { subject }.to change { previous_balance.reload.balance }.to(-100) }
      it { expect { subject }.to change { previous_balance.reload.being_processed } }
      it { expect { subject }.to change { previous_removal.reload.balance }.to(-600) }
      it { expect { subject }.to change { previous_removal.reload.being_processed } }
      it { expect { subject }.to change { balance_add.reload.amount }.to 600 }

      it { expect { subject }.to_not change { balance_add.reload.balance } }
      it { expect { subject }.to_not change { previous_removal.reload.amount } }
      it { expect { subject }.to_not change { balance.reload.being_processed } }

      context 'when counter has time off' do
        before { time_off.employee_balance = balance }
        let(:time_off) { create(:time_off, :without_balance, being_processed: true) }
        let(:balance_id) { balance.id }

        it { expect { subject }.to change { time_off.reload.being_processed } }
        it { expect { subject }.to change { time_off.employee_balance.reload.being_processed } }
      end
    end

    context 'and balance from current policy period is edited' do
      let(:balance_id) { balance.id }
      let(:options) { { amount: -100 } }

      it { expect { subject }.to change { balance.reload.amount }.to(-100) }
      it { expect { subject }.to change { balance.reload.balance }.to(-100) }
      it { expect { subject }.to change { balance.reload.being_processed } }

      it { expect { subject }.to_not change { previous_removal.reload.being_processed } }
      it { expect { subject }.to_not change { balance_add.reload.being_processed } }

      context 'when counter has time off' do
        before { time_off.employee_balance = balance }
        let(:time_off) { create(:time_off, :without_balance, being_processed: true) }
        let(:balance_id) { balance.id }

        it { expect { subject }.to change { time_off.reload.being_processed } }
        it { expect { subject }.to change { balance.reload.being_processed } }
      end
    end
  end

  context 'for employee balance which policy is a balancer' do
    context 'policy has end date' do
      include_context 'shared_context_balances',
        type: 'balancer',
        years_to_effect: 1,
        end_day: (Date.today + 1.year).day,
        end_month: (Date.today + 1.year).month

      context 'and in current policy period' do
        before { Employee::Balance.update_all(being_processed: true) }

        let(:balance_id) { balance.id }
        let(:options) { { amount: -400 } }

        it { expect { subject }.to change { balance.reload.amount }.to(-400) }
        it { expect { subject }.to change { balance.reload.balance }.to(600) }
        it { expect { subject }.to change { balance.reload.being_processed } }

        it { expect { subject }.to_not change { balance_add.reload.being_processed } }

        context 'and changes to previous policy' do
          context 'and policy does have end date' do
            context 'amount bigger than policy removal' do
              let(:options) { { effective_at: previous.first + 1.week, amount: -2000} }

              it { expect { subject }.to change { balance.reload.amount }.to(-2000) }
              it { expect { subject }.to change { balance.reload.balance }.to(-1000) }
              it { expect { subject }.to change { balance.reload.being_processed } }
              it { expect { subject }.to change { previous_removal.reload.being_processed } }
              it { expect { subject }.to change { previous_removal.reload.amount }.to(0) }
              it { expect { subject }.to change { previous_removal.reload.balance } }
              it { expect { subject }.to change { balance_add.reload.being_processed } }
              it { expect { subject }.to change { balance_add.reload.balance } }
            end

            context 'amount smaller or equal policy removal' do
              let(:options) { { effective_at: previous.first + 1.week, amount: -300 } }

              it { expect { subject }.to change { balance.reload.amount }.to(-300) }
              it { expect { subject }.to change { balance.reload.balance }.to(700) }
              it { expect { subject }.to change { balance.reload.being_processed } }
              it { expect { subject }.to change { previous_removal.reload.being_processed } }
              it { expect { subject }.to change { previous_removal.reload.amount }.to(-600) }
              it { expect { subject }.to change { balance_add.reload.being_processed } }

              it { expect { subject }.to_not change { previous_removal.reload.balance } }
              it { expect { subject }.to_not change { balance_add.reload.balance } }
            end
          end
        end
      end

      context 'and in previous policy period' do
        before { Employee::Balance.update_all(being_processed: true) }
        let(:balance_id) { previous_balance.id }

        context 'amount smaller or equal policy removal' do
          let(:options) { { amount: -1000 } }

          it { expect { subject }.to change { previous_balance.reload.amount }.to(-1000) }
          it { expect { subject }.to change { previous_balance.reload.balance }.to(0) }
          it { expect { subject }.to change { previous_balance.reload.being_processed } }
          it { expect { subject }.to change { previous_removal.reload.being_processed } }
          it { expect { subject }.to change { previous_removal.reload.amount }.to(0) }

          it { expect { subject }.to_not change { balance.reload.being_processed } }
          it { expect { subject }.to_not change { balance_add.reload.being_processed } }
          it { expect { subject }.to_not change { balance_add.reload.balance } }
        end

        context 'amount greater than policy removal' do
          let(:options) { { amount: -2000 } }

          it { expect { subject }.to change { previous_balance.reload.amount }.to(-2000) }
          it { expect { subject }.to change { previous_balance.reload.balance }.to(-1000) }
          it { expect { subject }.to change { previous_balance.reload.being_processed } }
          it { expect { subject }.to change { previous_removal.reload.being_processed } }
          it { expect { subject }.to change { previous_removal.reload.amount }.to(0) }

          it { expect { subject }.to change { balance.reload.being_processed } }
          it { expect { subject }.to change { balance.reload.balance } }
          it { expect { subject }.to change { balance_add.reload.being_processed } }
          it { expect { subject }.to change { balance_add.reload.balance } }
        end

        context 'amount is addition' do
          let(:options) { { amount: 2000 } }

          it { expect { subject }.to change { previous_balance.reload.amount }.to(2000) }
          it { expect { subject }.to change { previous_balance.reload.balance }.to(3000) }
          it { expect { subject }.to change { previous_balance.reload.being_processed } }
          it { expect { subject }.to change { previous_removal.reload.being_processed } }
          it { expect { subject }.to change { previous_removal.reload.amount }.to(-1000) }

          it { expect { subject }.to change { balance.reload.being_processed } }
          it { expect { subject }.to change { balance.reload.balance } }
          it { expect { subject }.to change { balance_add.reload.being_processed } }
          it { expect { subject }.to change { balance_add.reload.balance } }
        end

        context 'and now in current period' do
          let(:options) { { amount: -500, effective_at: current.last - 2.weeks } }

          it { expect { subject }.to change { previous_balance.reload.effective_at } }
          it { expect { subject }.to change { previous_balance.reload.balance }.to(500) }
          it { expect { subject }.to change { previous_balance.reload.being_processed } }
          it { expect { subject }.to change { previous_removal.reload.being_processed } }
          it { expect { subject }.to change { previous_removal.reload.amount }.to(-1000) }
          it { expect { subject }.to change { balance.reload.balance }.to(0) }

          it { expect { subject }.to change { balance.reload.being_processed } }
          it { expect { subject }.to change { balance_add.reload.being_processed } }

          it { expect { subject }.to_not change { balance_add.reload.balance } }
        end
      end
    end

    context 'policy does not have end date' do
      include_context 'shared_context_balances',
        type: 'balancer',
        years_to_effect: 1

      before { Employee::Balance.update_all(being_processed: true) }

      context 'balance in current policy' do
        let(:balance_id) { balance.id }
        let(:options) { { amount: 500 } }

        it { expect { subject }.to change { balance.reload.amount } }
        it { expect { subject }.to change { balance.reload.balance } }
        it { expect { subject }.to change { balance.reload.being_processed } }

        it { expect { subject }.to_not change { balance_add.reload.being_processed } }
        it { expect { subject }.to_not change { previous_balance.reload.being_processed } }

        context 'and now in previous' do
          let(:options) { { effective_at: previous.first + 2.days, amount: 500 } }

          it { expect { subject }.to change { balance.reload.amount } }
          it { expect { subject }.to change { balance.reload.balance } }
          it { expect { subject }.to change { balance.reload.being_processed } }
          it { expect { subject }.to change { previous_balance.reload.balance } }
          it { expect { subject }.to change { balance_add.reload.balance } }
        end
      end

      context 'balance in previous policy' do
        let(:balance_id) { previous_balance.id }
        let(:options) { {  amount: -100 } }

        it { expect { subject }.to change { previous_balance.reload.amount } }
        it { expect { subject }.to change { previous_balance.reload.balance } }
        it { expect { subject }.to change { balance.reload.being_processed } }
        it { expect { subject }.to change { balance_add.reload.balance } }

        context 'and now in current' do
          let(:options) {{ amount: -100, effective_at: current.last }}

          it { expect { subject }.to change { previous_balance.reload.amount } }
          it { expect { subject }.to change { previous_balance.reload.balance } }
          it { expect { subject }.to change { balance.reload.being_processed } }
          it { expect { subject }.to change { balance_add.reload.balance } }
        end
      end
    end
  end
end
