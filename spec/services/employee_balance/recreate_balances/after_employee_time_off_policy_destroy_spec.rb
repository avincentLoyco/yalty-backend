require 'rails_helper'

RSpec.describe RecreateBalances::AfterEmployeeTimeOffPolicyDestroy, type: :service do
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

  let!(:etop_to_destroy) do
    create(:employee_time_off_policy, employee: employee, time_off_policy: top_to_destroy,
      effective_at: destroyed_effective_at)
  end

  subject(:remove_etop) do
    etop_to_destroy.destroy!
  end

  subject(:call_service) do
    described_class.new(
      destroyed_effective_at: destroyed_effective_at,
      time_off_category_id: category.id,
      employee_id: employee.id
    ).call
  end

  subject(:create_balances_for_existing_etops) do
    EmployeeTimeOffPolicy.order(:effective_at).each do |etop|
      RecreateBalances::AfterEmployeeTimeOffPolicyCreate.new(
        new_effective_at: etop.effective_at,
        time_off_category_id: etop.time_off_category_id,
        employee_id: etop.employee_id
      ).call
    end
  end

  context 'when there are no etops after delete' do
    let(:destroyed_effective_at) { Time.zone.parse('2014-01-15') }
    let(:top_to_destroy) { create(:time_off_policy, :with_end_date, time_off_category: category) }

    before do
      create_balances_for_existing_etops
      remove_etop
      call_service
    end

    it { expect(employee.employee_balances.where(time_off_category: category).count).to eq(0) }
  end

  context 'when there are no etops after one removed' do
    let(:destroyed_effective_at) { Time.zone.parse('2015-10-01') }
    let(:top_to_destroy) do
      create(:time_off_policy, time_off_category: category, start_month: 2, end_day: 1,
        end_month: 5, years_to_effect: 1)
    end
    let(:top_a) { create(:time_off_policy, :with_end_date, time_off_category: category) }
    let!(:etop_a) do
      create(:employee_time_off_policy, employee: employee, time_off_policy: top_a,
        effective_at: Time.zone.parse('2013-01-02'))
    end

    context 'without time off' do
      let(:expeted_balances_dates) do
        ['2013-01-02', '2013-12-31', '2014-01-01', '2014-04-01', '2014-12-31', '2015-01-01',
         '2015-04-01', '2015-12-31', '2016-01-01', '2016-12-31', '2017-01-01', '2017-12-31',
         '2018-01-01'].map(&:to_date)
      end

      before do
        create_balances_for_existing_etops
        remove_etop
        call_service
      end

      it { expect(existing_balances_effective_ats).to match_array(expeted_balances_dates) }
    end

    context 'with time off' do
      let(:expeted_balances_dates) do
        ['2013-01-02', '2013-12-31', '2014-01-01', '2014-04-01', '2014-12-31', '2015-01-01',
         '2015-04-01', '2015-10-01', '2015-12-31', '2016-01-01', '2016-12-31', '2017-01-01',
         '2017-12-31', '2018-01-01'].map(&:to_date)
      end
      let(:time_off_effective_at) { destroyed_effective_at }
      let!(:time_off) do
        create(:time_off, employee: employee, time_off_category: category,
          start_time: time_off_effective_at - 5.days, end_time: time_off_effective_at)
      end

      before do
        create_balances_for_existing_etops
        validity_date =
          RelatedPolicyPeriod.new(etop_a).validity_date_for_balance_at(time_off.end_time)
        time_off.employee_balance.update!(validity_date: validity_date)
        remove_etop
        call_service
      end

      it { expect(existing_balances_effective_ats).to match_array(expeted_balances_dates) }
    end
  end

  context 'when there are etop after one removed' do
    let(:destroyed_effective_at) { Time.zone.parse('2015-10-01') }
    let(:top_to_destroy) do
      create(:time_off_policy, time_off_category: category, start_month: 2, end_day: 1,
        end_month: 5, years_to_effect: 1)
    end
    let(:tops) { create_list(:time_off_policy, 2, :with_end_date, time_off_category: category) }
    let!(:etop_a) do
      create(:employee_time_off_policy, employee: employee, time_off_policy: tops.first,
        effective_at: Time.zone.parse('2013-01-02'))
    end
    let!(:etop_b) do
      create(:employee_time_off_policy, employee: employee, time_off_policy: tops.second,
        effective_at: Time.zone.parse('2016-10-01'))
    end
    let(:expeted_balances_dates) do
      ['2013-01-02', '2013-12-31', '2014-01-01', '2014-04-01', '2014-12-31', '2015-01-01',
       '2015-04-01', '2015-12-31', '2016-01-01', '2016-10-01', '2016-12-31', '2017-01-01'
      ].map(&:to_date)
    end

    before do
      create_balances_for_existing_etops
      remove_etop
      call_service
    end

    it { expect(existing_balances_effective_ats).to match_array(expeted_balances_dates) }
  end
end
