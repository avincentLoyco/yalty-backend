require 'rails_helper'

RSpec.describe RecreateBalances::AfterEmployeeTimeOffPolicyUpdate, type: :service do
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

  subject(:update_etop) do
    etop_to_update.update!(effective_at: new_effective_at)
  end

  subject(:call_service) do
    described_class.new(
      new_effective_at: new_effective_at,
      old_effective_at: old_effective_at,
      time_off_category_id: category.id,
      employee_id: employee.id
    ).call
  end

  subject(:create_balances_for_existing_etops) do
    EmployeeTimeOffPolicy.order(:effective_at).each do |etop|
      validity_date = RelatedPolicyPeriod.new(etop).validity_date_for(etop.effective_at)
      CreateEmployeeBalance.new(etop.time_off_category_id, etop.employee_id, account.id,
        effective_at: etop.effective_at + 5.minutes, validity_date: validity_date).call
      ManageEmployeeBalanceAdditions.new(etop).call
    end
  end

  context 'to past' do
    context 'when there are no other etops' do
      let(:new_effective_at) { Time.zone.parse('2013-01-15') }
      let(:old_effective_at) { Time.zone.parse('2014-01-15') }
      let(:top_to_update) { create(:time_off_policy, :with_end_date, time_off_category: category) }
      let!(:etop_to_update) do
        create(:employee_time_off_policy, employee: employee, time_off_policy: top_to_update,
          effective_at: old_effective_at)
      end
      let(:expeted_balances_dates) do
        ['2013-01-15', '2013-12-31', '2014-01-01', '2014-12-31', '2015-01-01', '2015-04-01',
         '2015-12-31', '2016-01-01', '2016-12-31', '2017-01-01', '2017-12-31', '2018-01-01'
       ].map(&:to_date)
      end

      before do
        create_balances_for_existing_etops
        update_etop
        call_service
      end

      it { expect(existing_balances_effective_ats).to match_array(expeted_balances_dates) }
    end

    context 'when there are etop before updated one' do
      let(:old_effective_at) { Time.zone.parse('2015-06-01') }
      let(:top_to_update) do
        create(:time_off_policy, time_off_category: category, start_month: 2, end_day: 1,
          end_month: 5, years_to_effect: 1)
      end
      let!(:etop_to_update) do
        create(:employee_time_off_policy, employee: employee, time_off_policy: top_to_update,
          effective_at: old_effective_at)
      end
      let(:top_a) { create(:time_off_policy, :with_end_date, time_off_category: category) }
      let!(:etop_a) do
        create(:employee_time_off_policy, employee: employee, time_off_policy: top_a,
          effective_at: Time.zone.parse('2013-02-01'))
      end

      context 'with additions before new etop' do
        let(:old_effective_at) { Time.zone.parse('2015-06-01') }
        let(:new_effective_at) { Time.zone.parse('2014-02-01') }
        let(:expeted_balances_dates) do
          ['2013-02-01', '2013-12-31', '2014-01-01', '2014-02-01', '2014-04-01', '2015-01-31',
           '2015-02-01', '2015-04-01', '2015-05-01', '2016-01-31', '2016-02-01', '2017-01-31',
           '2017-02-01'].map(&:to_date)
        end

        before do
          create_balances_for_existing_etops
          update_etop
          call_service
        end

        it { expect(existing_balances_effective_ats).to match_array(expeted_balances_dates) }
      end

      context 'without additions before new etop' do
        let(:old_effective_at) { Time.zone.parse('2015-06-01 00:05:00') }
        let(:new_effective_at) { Time.zone.parse('2013-06-01') }

        context 'with time off' do
          let(:balances_dates_with_time_off) do
            ['2013-02-01', '2013-06-01', '2014-01-31', '2014-02-01', '2014-04-01', '2015-01-31',
             '2015-02-01', '2015-05-01', '2015-06-01', '2016-01-31', '2016-02-01', '2017-01-31',
             '2017-02-01'].map(&:to_date)
          end
          let(:time_off_effective_at) { old_effective_at - 5.minutes }
          let!(:time_off) do
            create(:time_off, employee: employee, time_off_category: category,
              start_time: time_off_effective_at - 5.days, end_time: time_off_effective_at)
          end

          before do
            create_balances_for_existing_etops
            validity_date =
              RelatedPolicyPeriod.new(etop_a).validity_date_for_balance_at(time_off.end_time)
            time_off.employee_balance.update!(validity_date: validity_date)
            update_etop
            call_service
          end

          it { expect(existing_balances_effective_ats).to match_array(balances_dates_with_time_off) }
        end

        context 'without time off' do
          let(:expeted_balances_dates) do
            ['2013-02-01', '2013-06-01', '2014-01-31', '2014-02-01', '2014-04-01', '2015-01-31',
             '2015-02-01', '2015-05-01', '2016-01-31', '2016-02-01', '2017-01-31', '2017-02-01',
            ].map(&:to_date)
          end

          before do
            create_balances_for_existing_etops
            update_etop
            call_service
          end

          it { expect(existing_balances_effective_ats).to match_array(expeted_balances_dates) }
        end
      end

      context 'when moving behind another etop' do
        let(:old_effective_at) { Time.zone.parse('2016-06-01') }
        let(:new_effective_at) { Time.zone.parse('2014-06-01') }
        let(:top_b) do
          create(:time_off_policy, :with_end_date, time_off_category: category, start_month: 2)
        end
        let!(:etop_b) do
          create(:employee_time_off_policy, employee: employee, time_off_policy: top_b,
            effective_at: Time.zone.parse('2014-10-01'))
        end

        let(:expeted_balances_dates) do
          ['2013-02-01', '2013-12-31', '2014-01-01', '2014-04-01', '2014-06-01', '2014-10-01',
           '2015-01-31', '2015-02-01', '2015-04-01', '2016-01-31', '2016-02-01', '2017-01-31',
           '2017-02-01'].map(&:to_date)
        end

        before do
          create_balances_for_existing_etops
          update_etop
          call_service
        end

        it { expect(existing_balances_effective_ats).to match_array(expeted_balances_dates) }
      end

      context 'when moving behind more than one etop' do
        let(:old_effective_at) { Time.zone.parse('2016-06-01') }
        let(:new_effective_at) { Time.zone.parse('2014-02-15') }
        let(:top_b) do
          create(:time_off_policy, :with_end_date, time_off_category: category, start_month: 2)
        end
        let!(:etop_b) do
          create(:employee_time_off_policy, employee: employee, time_off_policy: top_b,
            effective_at: Time.zone.parse('2014-10-01'))
        end
        let(:top_c) do
          create(:time_off_policy, :with_end_date, time_off_category: category)
        end
        let!(:etop_c) do
          create(:employee_time_off_policy, employee: employee, time_off_policy: top_c,
            effective_at: Time.zone.parse('2015-10-01'))
        end

        let(:expeted_balances_dates) do
          ['2013-02-01', '2013-12-31', '2014-01-01', '2014-02-15', '2014-04-01', '2014-10-01',
           '2015-01-31', '2015-02-01', '2015-04-01', '2015-10-01', '2015-12-31', '2016-01-01',
           '2016-12-31', '2017-01-01', '2017-12-31', '2018-01-01'].map(&:to_date)
        end

        before do
          create_balances_for_existing_etops
          update_etop
          call_service
        end

        it { expect(existing_balances_effective_ats).to match_array(expeted_balances_dates) }
      end
    end
  end

  context 'to future' do
    context 'when there are no other etops' do
      let(:old_effective_at) { Time.zone.parse('2013-01-15') }
      let(:new_effective_at) { Time.zone.parse('2014-10-01') }
      let(:top_to_update) { create(:time_off_policy, :with_end_date, time_off_category: category) }
      let!(:etop_to_update) do
        create(:employee_time_off_policy, employee: employee, time_off_policy: top_to_update,
          effective_at: old_effective_at)
      end
      let(:expeted_balances_dates) do
        ['2014-10-01', '2014-12-31', '2015-01-01', '2015-12-31', '2016-01-01', '2016-12-31',
         '2017-01-01', '2017-12-31', '2018-01-01'].map(&:to_date)
      end

      before do
        create_balances_for_existing_etops
        update_etop
        call_service
      end

      it { expect(existing_balances_effective_ats).to match_array(expeted_balances_dates) }
    end

    context 'with etop before moved one' do
      let(:old_effective_at) { Time.zone.parse('2014-10-01') }
      let(:new_effective_at) { Time.zone.parse('2015-10-01') }
      let(:top_to_update) do
        create(:time_off_policy, :with_end_date, time_off_category: category, start_month: 2)
      end
      let!(:etop_to_update) do
        create(:employee_time_off_policy, employee: employee, time_off_policy: top_to_update,
          effective_at: old_effective_at)
      end
      let(:top_a)  { create(:time_off_policy, :with_end_date, time_off_category: category) }
      let!(:etop_a) do
        create(:employee_time_off_policy, employee: employee, time_off_policy: top_a,
          effective_at: Time.zone.parse('2013-02-01'))
      end
      let(:expeted_balances_dates) do
        ['2013-02-01', '2013-12-31', '2014-01-01', '2014-04-01', '2014-12-31', '2015-01-01',
         '2015-04-01', '2015-10-01', '2016-01-31', '2016-02-01', '2017-01-31', '2017-02-01'
        ].map(&:to_date)
      end

      before do
        create_balances_for_existing_etops
        update_etop
        call_service
      end

      it { expect(existing_balances_effective_ats).to match_array(expeted_balances_dates) }
    end

    context 'when moved etop is between other two' do
      let(:old_effective_at) { Time.zone.parse('2014-10-01') }
      let(:new_effective_at) { Time.zone.parse('2015-10-01') }
      let(:top_to_update) do
        create(:time_off_policy, :with_end_date, time_off_category: category, start_month: 2)
      end
      let!(:etop_to_update) do
        create(:employee_time_off_policy, employee: employee, time_off_policy: top_to_update,
          effective_at: old_effective_at)
      end
      let(:tops) { create_list(:time_off_policy, 2, :with_end_date, time_off_category: category) }
      let!(:etop_a) do
        create(:employee_time_off_policy, employee: employee, time_off_policy: tops.first,
          effective_at: Time.zone.parse('2013-02-01'))
      end
      let!(:etop_b) do
        create(:employee_time_off_policy, employee: employee, time_off_policy: tops.second,
          effective_at: Time.zone.parse('2016-06-01'))
      end
      let(:expeted_balances_dates) do
        ['2013-02-01', '2013-12-31', '2014-01-01', '2014-04-01', '2014-12-31', '2015-01-01',
         '2015-04-01', '2015-10-01', '2016-01-31', '2016-02-01', '2016-06-01', '2016-12-31',
         '2017-01-01'].map(&:to_date)
      end

      before do
        create_balances_for_existing_etops
        update_etop
        call_service
      end

      it { expect(existing_balances_effective_ats).to match_array(expeted_balances_dates) }
    end

    context 'moving etop after another one' do
      let(:old_effective_at) { Time.zone.parse('2013-10-01') }
      let(:new_effective_at) { Time.zone.parse('2015-10-01') }
      let(:top_to_update) do
        create(:time_off_policy, :with_end_date, time_off_category: category, start_month: 2)
      end
      let!(:etop_to_update) do
        create(:employee_time_off_policy, employee: employee, time_off_policy: top_to_update,
          effective_at: old_effective_at)
      end
      let(:tops) { create_list(:time_off_policy, 2, :with_end_date, time_off_category: category) }
      let!(:etop_a) do
        create(:employee_time_off_policy, employee: employee, time_off_policy: tops.first,
          effective_at: Time.zone.parse('2013-02-01'))
      end
      let!(:etop_b) do
        create(:employee_time_off_policy, employee: employee, time_off_policy: tops.second,
          effective_at: Time.zone.parse('2015-03-01'))
      end
      let(:expeted_balances_dates) do
        ['2013-02-01', '2013-12-31', '2014-01-01', '2014-04-01', '2014-12-31', '2015-01-01',
         '2015-03-01', '2015-04-01', '2015-10-01', '2016-01-31', '2016-02-01', '2017-01-31',
         '2017-02-01'].map(&:to_date)
      end

      before do
        create_balances_for_existing_etops
        update_etop
        call_service
      end

      it { expect(existing_balances_effective_ats).to match_array(expeted_balances_dates) }
    end
  end
end
