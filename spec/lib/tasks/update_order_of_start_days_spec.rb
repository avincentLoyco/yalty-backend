require 'rails_helper'
require 'rake'

RSpec.describe 'update_order_of_start_days', type: :rake do
  include_context 'shared_context_timecop_helper'
  include_context 'shared_context_account_helper'
  include_context 'rake'

  let(:account) { presence_policy.account }
  let(:employee) { create(:employee, account: account) }
  let(:presence_policy) { create(:presence_policy, :with_time_entries, number_of_days: 7) }
  let!(:categories) { create_list(:time_off_category, 2, account: account) }
  let!(:epp) do
    create(:employee_presence_policy,
      effective_at: employee.hired_date, order_of_start_day: Date.today.wday,
      employee: employee, presence_policy: presence_policy)
  end

  let!(:balances_after) do
    categories.map do |category|
      create_list(:employee_balance, 2, time_off_category: category, employee: employee)
    end
  end

  subject { rake['update_order_of_start_days'].invoke }

  context 'when epp has valid order of start day' do
    it { expect { subject }.to_not change { epp.reload.order_of_start_day } }

    it 'does not change balances being processed flag' do
      subject
      balances_after.flatten.map do |balance|
        expect(balance.reload.being_processed).to eq false
      end
    end
  end

  context 'when epp does not have valid order of start day' do
    before { epp.update!(order_of_start_day: 6) }

    it { expect { subject }.to change { epp.reload.order_of_start_day }.to(5) }

    it 'changes balances being processed flag' do
      subject
      balances_after.flatten.map do |balance|
        expect(balance.reload.being_processed).to eq true
      end
    end
  end
end
