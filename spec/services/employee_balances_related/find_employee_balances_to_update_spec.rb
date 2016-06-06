require 'rails_helper'

RSpec.describe FindEmployeeBalancesToUpdate, type: :service do
  include_context 'shared_context_account_helper'
  include_context 'shared_context_timecop_helper'

  let(:account) { create(:account) }
  let(:employee) { create(:employee, account: account) }

  subject { FindEmployeeBalancesToUpdate.new(resource, options).call }
  let(:options) { {} }

  context 'when time off policy is a counter type' do
    include_context 'shared_context_balances',
      type: 'counter',
      years_to_effect: 0

    context 'when resource is last in category and no effective_at date given' do
      let(:resource) { balance }

      it { expect(subject).to include(balance.id) }
      it { expect(subject).to_not include (balance_add.id) }
    end

    context 'when effective_at date given' do
      let(:resource) { previous_removal }
      let(:options) { { effective_at: Date.today - 1.month } }

      it { expect(subject).to include(previous_removal.id,  balance_add.id, balance.id) }
      it { expect(subject).to_not include(previous_balance.id) }
    end

    context 'when option update all send' do
      let(:options) { { update_all: true } }
      let(:resource) { previous_removal }

      it { expect(subject).to include(balance.id, balance_add.id, previous_removal.id) }
      it { expect(subject).to_not include(previous_balance.id) }
    end

    context 'when resource in current or next period' do
      let(:resource) { balance_add }

      it { expect(subject).to include(balance.id, balance_add.id) }
      it { expect(subject).to_not include(previous_balance.id) }
    end

    context 'when new effective at in previous policy period' do
      let(:resource) { balance_add }
      let(:options) { { effective_at: previous_removal.effective_at - 1.day } }

      it { expect(subject).to include(balance.id, balance_add.id, previous_removal.id) }
      it { expect(subject).to_not include(previous_balance.id) }
    end

    context 'when new effective at in current policy period' do
      let(:resource) { previous_removal }
      let(:options) { { effective_at: Time.now + 1.day } }

      it { expect(subject).to include(balance.id, balance_add.id, previous_removal.id) }
      it { expect(subject).to_not include(previous_balance.id) }
    end

    context 'when effective at in previous employee time off policy' do
      let(:resource) { previous_balance }

      it { expect(subject).to include(previous_removal.id, balance_add.id) }
      it { expect(subject).to_not include(balance.id) }
    end
  end

  context 'when time off policy is a balancer type' do
    include_context 'shared_context_balances',
      type: 'balancer',
      years_to_effect: 1,
      end_month: 4,
      end_day: 1

    context 'when employee balance last in category and no effective at given' do
      let(:resource) { balance }

      it { expect(subject).to include(balance.id) }
      it { expect(subject).to_not include (balance_add.id) }
    end

    context 'when options effective at given' do
      let(:resource) { balance }
      let(:options) { { effective_at: Time.now - 9.months } }

      it { expect(subject).to include(balance.id, balance_add.id, previous_balance.id) }
      it { expect(subject).to_not include(previous_add.id) }
    end

    context 'when amount option send and resource in previous period' do
      let(:resource) { previous_balance }

      context 'when new amount bigger than removal' do
        let(:options) { { amount: -900 } }

        it { expect(subject).to include(previous_balance.id, previous_removal.id) }
        it { expect(subject).to_not include(balance_add.id) }
      end

      context 'when new amount eq removal' do
        let(:options) { { amount: -1000 } }

        it { expect(subject).to include(previous_balance.id, previous_removal.id) }
        it { expect(subject).to_not include(balance_add.id) }
      end

      context 'when new amount smaller than removal' do
        let(:options) { { amount: -1100 } }

        it { expect(subject).to include(previous_balance.id, previous_removal.id, balance_add.id) }
      end
    end
  end
end
