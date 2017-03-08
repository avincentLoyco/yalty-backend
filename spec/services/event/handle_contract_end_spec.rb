require 'rails_helper'

RSpec.describe HandleContractEnd, type: :service do
  include_context 'shared_context_account_helper'
  include_context 'shared_context_timecop_helper'

  subject(:create_contract_end) do
    params = {
      effective_at: Time.zone.parse('2016/03/01'),
      event_type: 'contract_end',
      employee: { id: employee.id }
    }
    CreateEvent.new(params, {}).call
  end

  let!(:account) { create(:account) }
  let!(:employee) { create(:employee, account: account) }

  let!(:time_off_categories) { create_list(:time_off_category, 2, account: account) }
  let!(:presence_policies) { create_list(:presence_policy, 2, :with_presence_day, account: account) }
  let!(:working_places) { create_list(:working_place, 2, account: account) }

  let!(:time_off_policies_before) do
    time_off_categories.map do |category|
      create(:time_off_policy, :with_end_date, time_off_category: category)
    end
  end
  let!(:time_off_policies_after) do
    time_off_categories.map do |category|
      create(:time_off_policy, :with_end_date, time_off_category: category)
    end
  end

  let!(:etops_before) do
    time_off_policies_before.map do |policy|
      create(:employee_time_off_policy, :with_employee_balance,
        time_off_policy: policy, employee: employee, effective_at: Date.new(2011, 1, 1))
    end
  end
  let!(:etops_after) do
    time_off_policies_after.map do |policy|
      create(:employee_time_off_policy, :with_employee_balance,
        time_off_policy: policy, employee: employee, effective_at: 6.months.from_now)
    end
  end

  let!(:epp_before) do
    create(:employee_presence_policy, employee: employee, presence_policy: presence_policies.first,
      effective_at: Time.zone.now)
  end
  let!(:epp_after) do
    create(:employee_presence_policy, employee: employee, presence_policy: presence_policies.last,
      effective_at: 6.months.from_now)
  end

  let!(:ewp_before) do
    create(:employee_working_place, employee: employee, working_place: working_places.first,
      effective_at: Time.zone.now)
  end
  let!(:ewp_after) do
    create(:employee_working_place, employee: employee, working_place: working_places.last,
      effective_at: 6.months.from_now)
  end

  let!(:time_offs) do
    [
      ['2011/1/1', '2011/1/10'],
      ['2016/2/20', '2016/3/10'],
      ['2016/3/15', '2016/3/20']
    ].map do |dates|
      create(:time_off, employee: employee, time_off_category: time_off_categories.first,
        start_time: dates[0].to_date, end_time: dates[1].to_date)
    end
  end

  before do
    Account.current = account
    TimeOff.all.map do |time_off|
      validity_date =
        RelatedPolicyPeriod
          .new(time_off.employee_balance.employee_time_off_policy)
          .validity_date_for(time_off.end_time)
      next unless validity_date.present?
      time_off.employee_balance.update!(validity_date: validity_date)
    end
    create_contract_end
  end

  context 'removed and modified resources' do
    it { expect(employee.employee_time_off_policies).to_not include(etops_after) }
    it { expect(employee.employee_presence_policies).to_not include(epp_after) }
    it { expect(employee.employee_working_places).to_not include(ewp_after) }
    it { expect(employee.time_offs).to_not include(time_offs.last) }
    it 'moves end_time to contract_end date' do
      expect(employee.time_offs.order(:start_time).last.end_time)
        .to eq(Time.zone.parse('2016/03/02'))
    end
  end

  context 'assigned reset resources' do
    let(:removal_balance) do
      time_off_categories.first.employee_balances.order(:effective_at).last
    end
    it do
      expect(
        employee.employee_time_off_policies.where(time_off_category: time_off_categories.last)
      .order(:effective_at).last.time_off_policy.reset).to eq true
    end
    it do
      expect(
        employee.employee_time_off_policies.where(time_off_category: time_off_categories.first)
      .order(:effective_at).last.time_off_policy.reset).to eq true
    end
    it do
      expect(employee.employee_presence_policies.order(:effective_at).last.presence_policy.reset)
        .to be(true)
    end
    it do
      expect(employee.employee_working_places.order(:effective_at).last.working_place.reset)
        .to be(true)
    end
    it do
      expect(time_off_categories.first.employee_balances.order(:effective_at).last.reset_balance)
        .to be true
    end
    it do
      expect(time_off_categories.last.employee_balances.order(:effective_at).last.reset_balance)
        .to be true
    end
    it { expect(removal_balance.amount).to eq (-time_offs.second.employee_balance.balance) }
    it do
      expect(time_offs.second.employee_balance.reload.balance_credit_removal_id)
        .to eq removal_balance.id
    end
    it do
      expect(time_offs.second.employee_balance.reload.validity_date)
        .to eq removal_balance.effective_at
    end
  end
end
