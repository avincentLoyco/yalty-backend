require 'rails_helper'

RSpec.describe RecreateBalances::AfterEmployeeTimeOffPolicyCreate, type: :service do
  include_context 'shared_context_timecop_helper'
  include ActiveJob::TestHelper

  let!(:account) { create(:account) }
  let!(:employee) { create(:employee, account: account) }
  let!(:category) { create(:time_off_category, account: account) }

  let!(:second_category) { create(:time_off_category, account: account) }
  let(:top_for_second_category) { create(:time_off_policy, time_off_category: second_category) }
  let!(:etop_in_different_category) do
    create(:employee_time_off_policy, employee: employee, time_off_policy: top_for_second_category,
      effective_at: Time.zone.parse('2015-01-01'))
  end
  let(:existing_balances_effective_ats) do
    employee.employee_balances.where(time_off_category: category).pluck(:effective_at)
      .map(&:to_date)
  end

  subject(:create_new_etop) do
    create(:employee_time_off_policy, employee: employee, time_off_policy: new_top,
      effective_at: new_effective_at)
  end

  subject(:call_service) do
    described_class.new(
      new_effective_at: new_effective_at,
      time_off_category_id: category.id,
      employee_id: employee.id
    ).call
  end

  subject(:create_balances_for_existing_etops) do
    EmployeeTimeOffPolicy.order(:effective_at).each do |etop|
      validity_date = RelatedPolicyPeriod.new(etop).validity_date_for(etop.effective_at)
      CreateEmployeeBalance.new(etop.time_off_category_id, etop.employee_id, account.id,
        effective_at: etop.effective_at, validity_date: validity_date).call
      ManageEmployeeBalanceAdditions.new(etop).call
    end
  end

  context 'when there are no etops' do
    let(:new_effective_at) { Time.zone.parse('2013-02-01') }
    let(:new_top) do
      create(:time_off_policy, :with_end_date, time_off_category: category, amount: 1000)
    end
    let(:expeted_balances_dates) do
      ['2013-02-01', '2013-12-31', '2014-01-01', '2014-04-01', '2014-12-31', '2015-01-01',
       '2015-04-01', '2015-12-31', '2016-01-01', '2016-12-31', '2017-01-01', '2017-12-31',
       '2018-01-01'].map(&:to_date)
    end

    before do
      create_new_etop
      call_service
    end

    it { expect(existing_balances_effective_ats).to match_array(expeted_balances_dates) }
  end

  context 'when there is etop before new one' do
    let(:new_effective_at) { Time.zone.parse('2014-04-15') }
    let(:new_top) do
      create(:time_off_policy, time_off_category: category, amount: 500, start_month: 2,
        end_day: 1, end_month: 5, years_to_effect: 1)
    end
    let(:expeted_balances_dates) do
      ['2013-02-01', '2013-12-31', '2014-01-01', '2014-04-01', '2014-04-15', '2015-01-31',
       '2015-02-01', '2015-04-01', '2016-01-31', '2016-02-01', '2017-01-31', '2017-02-01'
      ].map(&:to_date)
    end
    let(:top_a) do
      create(:time_off_policy, :with_end_date, time_off_category: category, amount: 1000)
    end
    let!(:etop_a) do
      create(:employee_time_off_policy, employee: employee, time_off_policy: top_a,
        effective_at: Time.zone.parse('2013-02-01'))
    end

    before do
      create_balances_for_existing_etops
      create_new_etop
      call_service
    end

    it { expect(existing_balances_effective_ats).to match_array(expeted_balances_dates) }
  end

  context 'when there is etop after new one' do
    let(:new_effective_at) { Time.zone.parse('2014-01-02') }
    let(:new_top) do
      create(:time_off_policy, time_off_category: category, amount: 500, start_month: 2,
        end_day: 1, end_month: 5, years_to_effect: 1)
    end
    let(:expeted_balances_dates) do
      ['2013-02-01', '2013-12-31', '2014-01-01', '2014-01-02', '2014-01-31', '2014-02-01',
       '2014-04-01', '2015-01-31', '2015-02-01', '2015-04-01', '2015-05-01', '2015-06-01',
       '2015-12-31', '2016-01-01', '2016-12-31', '2017-01-01', '2017-12-31', '2018-01-01'
      ].map(&:to_date)
    end
    let(:tops) do
      create_list(:time_off_policy, 2, :with_end_date, time_off_category: category, amount: 1000)
    end
    let!(:etop_a) do
      create(:employee_time_off_policy, employee: employee, time_off_policy: tops.first,
        effective_at: Time.zone.parse('2013-02-01'))
    end
    let!(:etop_b) do
      create(:employee_time_off_policy, employee: employee, time_off_policy: tops.second,
        effective_at: Time.zone.parse('2015-06-01'))
    end

    before do
      create_balances_for_existing_etops
      create_new_etop
      call_service
    end

    it { expect(existing_balances_effective_ats).to match_array(expeted_balances_dates) }
  end

  context 'when there is time-off associated with removal' do
    let(:new_effective_at) { Time.zone.parse('2013-10-01') }
    let(:new_top) do
      create(:time_off_policy, time_off_category: category, amount: 500, end_day: 1, end_month: 5,
        years_to_effect: 1)
    end
    let(:expeted_balances_dates) do
      ['2013-01-01', '2013-01-31', '2013-02-01', '2013-10-01', '2013-12-31', '2014-01-01',
       '2014-04-01', '2014-12-31', '2015-01-01', '2015-01-15', '2015-04-01', '2015-05-01',
       '2015-12-31', '2016-01-01', '2016-12-31', '2017-01-01', '2017-12-31', '2018-01-01'
      ].map(&:to_date)
    end
    let(:top_a) do
      create(:time_off_policy, :with_end_date, time_off_category: category, amount: 1000,
        start_month: 2)
    end
    let!(:etop_a) do
      create(:employee_time_off_policy, employee: employee, time_off_policy: top_a,
        effective_at: Time.zone.parse('2013-01-01'))
    end
    let!(:time_off) do
      create(:time_off, employee: employee, time_off_category: category,
        start_time: Time.zone.parse('2014-12-24'), end_time: Time.zone.parse('2015-01-15'))
    end

    before do
      create_balances_for_existing_etops
      validity_date =RelatedPolicyPeriod.new(etop_a).validity_date_for_balance_at(time_off.end_time)
      time_off.employee_balance.update!(validity_date: validity_date)
      create_new_etop
      call_service
    end

    it { expect(existing_balances_effective_ats).to match_array(expeted_balances_dates) }
  end
end
