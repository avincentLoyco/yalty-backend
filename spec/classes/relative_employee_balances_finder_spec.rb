require 'rails_helper'

RSpec.describe RelativeEmployeeBalancesFinder do
  include_context 'shared_context_account_helper'
  include_context 'shared_context_balances',
    type: 'balancer',
    years_to_effect: '1',
    end_day: 1,
    end_month: 4

  let(:account) { create(:account) }
  let(:employee) { create(:employee, account: account) }
  subject { RelativeEmployeeBalancesFinder.new(resource) }

  describe '#previous_balances' do
    let(:resource) { balance_add }

    it { expect(subject.previous_balances.pluck(:id))
      .to include(previous_add.id, previous_balance.id) }
    it { expect(subject.previous_balances.pluck(:id)).to_not include(balance.id, balance_add.id) }
  end

  describe '#next_balance' do
    let(:resource) { balance_add }

    it { expect(subject.next_balance).to include(balance.id) }
    it { expect(subject.next_balance).to_not include(previous_balance.id) }
  end

  describe '#active_balances' do
    let(:resource) { previous_balance }

    it { expect(subject.active_balances.pluck(:id)).to include(previous_add.id) }
    it { expect(subject.active_balances.pluck(:id)).to_not include(previous_removal.id) }
  end

  describe '#balances_related_by_category_and_employee' do
    let(:resource) { balance }
    let(:not_related) { create(:employee_balance) }

    it { expect(subject.balances_related_by_category_and_employee.pluck(:id))
      .to include(previous_add.id, previous_balance.id, balance_add.id) }
    it { expect(subject.balances_related_by_category_and_employee).to_not include(not_related.id) }
  end
end
