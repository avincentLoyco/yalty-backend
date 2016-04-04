require 'rails_helper'

RSpec.describe CalculateEmployeeBalanceRemovalAmount, type: :service do
  include_context 'shared_context_account_helper'
  subject { CalculateEmployeeBalanceRemovalAmount.new(balance, addition).call }

  let(:account) { create(:account) }
  let(:employee) { create(:employee, account: account) }

  context 'when employee balance has policy counter type' do
    include_context 'shared_context_balances',
      type: 'counter',
      years_to_effect: 1

    let(:addition) { nil }

    context 'and there were previous balances' do
      let(:balance) { balance_add }

      context 'and their balance bigger than 0' do
        before { previous_removal.update!(amount: 5000) }
        it { expect(subject).to eq -4000 }
      end

      context 'and their balance smaller than 0' do
        it { expect(subject).to eq 1500 }
      end

      context 'and their balance equal 0' do
        before { previous_removal.update!(amount: 1000) }

        it { expect(subject).to eq 0 }
      end
    end

    context 'and employee balance is first' do
      let(:balance) { previous_balance }

      it { expect(subject).to eq 0 }
    end
  end

  context 'when employee balance has policy balancer type' do
    include_context 'shared_context_balances',
      type: 'balancer',
      years_to_effect: 1,
      end_day: 1,
      end_month: 4

    let(:balance) { previous_removal }
    let(:addition) { previous_add }
    let!(:negative_balance) do
      create(:employee_balance,
        employee: employee, time_off_category: category, amount: -600,
        effective_at: previous.first + 4.months
      )
    end

    context 'only negative balances' do
      it { expect(subject).to eq -300 }
    end

    context 'positive balances in balance period' do
      let!(:positive_balance) do
        create(:employee_balance,
          employee: employee, time_off_category: category, amount: 600,
          effective_at: previous.first + 5.months
        )
      end

      context 'and amount is negative' do
        it { expect(subject).to eq -300 }
      end

      context 'and amount is positive' do
        before { positive_balance.update!(amount: 1500) }

        it { expect(subject).to eq -300 }
      end
    end

    context 'employee balances with validity dates in balance period' do
      let!(:positive_balance) do
        create(:employee_balance,
          employee: employee, time_off_category: category, amount: 600,
          effective_at: previous.first + 5.months, validity_date: Time.now + 2.months
        )
      end

      it { expect(subject).to eq -300 }
    end
  end
end
