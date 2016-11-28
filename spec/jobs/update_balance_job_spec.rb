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
      let(:options) { { resource_amount: -100 } }

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
        let(:time_off) do
          create(:time_off, :without_balance, :processed,
            employee: employee, time_off_category: category)
        end
        let(:balance_id) { balance.id }

        it { expect { subject }.to change { time_off.reload.being_processed } }
        it { expect { subject }.to change { time_off.employee_balance.reload.being_processed } }
      end
    end

    context 'and balance from current policy period is edited' do
      let(:balance_id) { balance.id }
      let(:options) { { manual_amount: -100 } }

      it { expect { subject }.to change { balance.reload.amount }.to(-100) }
      it { expect { subject }.to change { balance.reload.balance }.to(-100) }
      it { expect { subject }.to change { balance.reload.being_processed } }

      it { expect { subject }.to_not change { previous_removal.reload.being_processed } }
      it { expect { subject }.to_not change { balance_add.reload.being_processed } }

      context 'when counter has time off' do
        before { time_off.employee_balance = balance }
        let(:time_off) do
          create(:time_off, :without_balance, :processed,
            employee: employee, time_off_category: category)
        end
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
        let(:options) { { manual_amount: -400 } }

        it { expect { subject }.to change { balance.reload.amount }.to(-400) }
        it { expect { subject }.to change { balance.reload.balance }.to(600) }
        it { expect { subject }.to change { balance.reload.being_processed } }

        it { expect { subject }.to_not change { balance_add.reload.being_processed } }

        context 'and changes to previous policy' do
          context 'and policy does have end date' do
            before do
              balance.time_off.update!(
                end_time: new_effective_at, start_time: new_effective_at - 1.day)
            end
            let(:new_effective_at) { previous.first + 1.week }

            shared_examples 'Update of balances being_processed flag' do
              it { expect { subject }.to change { balance.reload.being_processed } }
              it { expect { subject }.to change { previous_removal.reload.being_processed } }
              it { expect { subject }.to change { balance_add.reload.being_processed } }
            end

            context 'amount bigger than policy removal' do
              let(:options) { { effective_at: new_effective_at, manual_amount: -2000} }

              it { expect { subject }.to change { balance.reload.amount }.to(-2000) }
              it { expect { subject }.to change { balance.reload.balance }.to(-1000) }
              it { expect { subject }.to change { previous_removal.reload.amount }.to(0) }

              it { expect { subject }.to change { previous_removal.reload.balance } }
              it { expect { subject }.to change { balance_add.reload.balance } }

              it_behaves_like 'Update of balances being_processed flag'
            end

            context 'amount smaller or equal policy removal' do
              let(:options) { { effective_at: new_effective_at, manual_amount: -300 } }

              it { expect { subject }.to change { balance.reload.amount }.to(-300) }
              it { expect { subject }.to change { balance.reload.balance }.to(700) }
              it { expect { subject }.to change { previous_removal.reload.amount }.to(-600) }

              it { expect { subject }.to_not change { previous_removal.reload.balance } }
              it { expect { subject }.to_not change { balance_add.reload.balance } }

              it_behaves_like 'Update of balances being_processed flag'
            end
          end
        end
      end

      context 'and in previous policy period' do
        before { Employee::Balance.update_all(being_processed: true) }
        let(:balance_id) { previous_balance.id }

        shared_examples 'Update of current period balances params' do
          it { expect { subject }.to change { balance.reload.being_processed } }
          it { expect { subject }.to change { balance.reload.balance } }
          it { expect { subject }.to change { balance_add.reload.being_processed } }
          it { expect { subject }.to change { balance_add.reload.balance } }
        end

        shared_examples 'Update of previous period balances params' do
          it { expect { subject }.to change { previous_balance.reload.being_processed } }
          it { expect { subject }.to change { previous_removal.reload.being_processed } }
        end

        context 'amount smaller or equal policy removal' do
          let(:options) { { manual_amount: -1000 } }

          it { expect { subject }.to change { previous_balance.reload.amount }.to(-1000) }
          it { expect { subject }.to change { previous_balance.reload.balance }.to(0) }
          it { expect { subject }.to change { previous_removal.reload.amount }.to(0) }

          it { expect { subject }.to_not change { balance.reload.being_processed } }
          it { expect { subject }.to_not change { balance_add.reload.being_processed } }
          it { expect { subject }.to_not change { balance_add.reload.balance } }

          it_behaves_like 'Update of previous period balances params'
        end

        context 'amount greater than policy removal' do
          let(:options) { { manual_amount: -2000 } }

          it { expect { subject }.to change { previous_balance.reload.amount }.to(-2000) }
          it { expect { subject }.to change { previous_balance.reload.balance }.to(-1000) }
          it { expect { subject }.to change { previous_removal.reload.amount }.to(0) }

          it_behaves_like 'Update of previous period balances params'
          it_behaves_like 'Update of current period balances params'
        end

        context 'amount is addition' do
          let(:options) { { manual_amount: 2000, validity_date: '1/4/2016' } }

          it { expect { subject }.to change { previous_balance.reload.amount }.to(2000) }
          it { expect { subject }.to change { previous_balance.reload.balance }.to(3000) }
          it { expect { subject }.to change { previous_removal.reload.amount }.to(-1000) }

          it_behaves_like 'Update of previous period balances params'
          it_behaves_like 'Update of current period balances params'
        end

        context 'and now in current period' do
          before do
            previous_balance.time_off.update!(end_time: '1/3/2017', start_time: '28/2/2017')
          end
          let(:options) { { manual_amount: -500, effective_at: '1/3/2017' } }

          it { expect { subject }.to change { previous_balance.reload.effective_at } }
          it { expect { subject }.to change { previous_balance.reload.balance }.to(500) }
          it { expect { subject }.to change { previous_removal.reload.amount }.to(-1000) }

          it { expect { subject }.to change { balance.reload.being_processed } }
          it { expect { subject }.to change { balance_add.reload.being_processed } }

          it { expect { subject }.to_not change { balance_add.reload.balance } }

          it_behaves_like 'Update of previous period balances params'
        end
      end
    end

    context 'policy does not have end date' do
      include_context 'shared_context_balances',
        type: 'balancer',
        years_to_effect: 1

      before { Employee::Balance.update_all(being_processed: true) }

      shared_examples 'Update of current period balances' do
        it { expect { subject }.to change { balance.reload.amount } }
        it { expect { subject }.to change { balance.reload.balance } }
        it { expect { subject }.to change { balance.reload.being_processed } }
      end

      shared_examples 'Update of previous period balances' do
        it { expect { subject }.to change { previous_balance.reload.amount } }
        it { expect { subject }.to change { previous_balance.reload.balance } }
        it { expect { subject }.to change { balance.reload.being_processed } }
        it { expect { subject }.to change { balance_add.reload.balance } }
      end

      context 'balance in current policy' do
        let(:balance_id) { balance.id }
        let(:options) { { manual_amount: 500 } }

        it { expect { subject }.to_not change { balance_add.reload.being_processed } }
        it { expect { subject }.to_not change { previous_balance.reload.being_processed } }

        it_behaves_like 'Update of current period balances'

        context 'and now in previous' do
          before do
            balance.time_off.update!(
              end_time: previous.first + 2.days, start_time: previous.first + 1.day)
          end
          let(:options) { { effective_at: previous.first + 2.days, manual_amount: 500 } }

          it { expect { subject }.to change { previous_balance.reload.balance } }
          it { expect { subject }.to change { balance_add.reload.balance } }

          it_behaves_like 'Update of current period balances'
        end
      end

      context 'balance in previous policy' do
        let(:balance_id) { previous_balance.id }
        let(:options) { {  manual_amount: -100 } }

        it_behaves_like 'Update of previous period balances'

        context 'and now in current' do
          let(:options) {{ manual_amount: -100, effective_at: current.last }}

          it_behaves_like 'Update of previous period balances'
        end
      end
    end

    context 'when emplyee has few time off policies, working places, holidays, presence policies' do
      before do
        employee.first_employee_event.update!(effective_at: Time.now - 4.years)
        ewp_first.update!(effective_at: Time.now - 4.years, working_place: wps.first)
        etop_first = create(:employee_time_off_policy, :with_employee_balance, employee: employee,
          time_off_policy: top_first, effective_at: 2.years.ago)
        etop_second
        create(:employee_balance_manual, employee: employee, time_off_category: category,
          effective_at: Date.new(etop_first.effective_at.year + 1, top_first.end_month, top_first.end_day),
          balance_credit_additions: [employee.employee_balances.order(:effective_at).first],
          resource_amount: -1000
        )
        create(:employee_balance, employee: employee, time_off_category: category,
          effective_at: etop_second.effective_at, resource_amount: top_second.amount,
          policy_credit_addition: true)
        Employee::Balance.update_all(being_processed: true)
      end

      let(:category) { create(:time_off_category, account: account) }
      let(:existing_balances) { Employee::Balance.where.not(id: balance.id).order(:effective_at) }
      let!(:top_first) do
        create(:time_off_policy, :with_end_date, time_off_category: category, amount: 1000)
      end
      let!(:top_second) { create(:time_off_policy, time_off_category: category, amount: 2000) }
      let!(:ewp_first) do
        create(:employee_working_place,
          effective_at: Time.now - 4.years, employee: employee, working_place: wps.first)
      end
      let(:ewp_second) do
        create(:employee_working_place,
          effective_at: Date.new(2015,9,24), employee: employee, working_place: wps.last)
      end
      let(:hps) do
        ['ai', 'ow'].map { |region| create(:holiday_policy, region: region, country: 'ch') }
      end
      let(:wps) do
        [hps.first, hps.last].map do |hp|
          create(:working_place, account: account, holiday_policy: hp)
        end
      end
      let(:etop_second_effective_at) { 1.year.ago }
      let(:etop_second) do
        create(:employee_time_off_policy, :with_employee_balance, employee: employee,
          time_off_policy: top_second, effective_at: etop_second_effective_at)
      end

      context 'when employee balance is updated' do
        subject { UpdateBalanceJob.perform_now(balance_id, options) }
        let(:balance) do
          create(:employee_balance, :processing, employee: employee, time_off_category: category,
            effective_at: etop_second.effective_at, resource_amount: 100)
        end
        context '' do
          let(:balance_id) { balance.id }
          let(:options) {{ resource_amount: 50 }}

          it 'has proper employee balances effective_at in database' do
            expect(existing_balances.pluck(:effective_at).map(&:to_date)).to eql(
              ['1/1/2014', '1/1/2015', '1/4/2015', '1/1/2016'].map(&:to_date)
            )
          end

          it { expect(existing_balances.map(&:amount)).to eql([1000, 2000, -1000, 2000]) }
        end

        context 'with removal' do
          context 'and removal is in the past' do
            let(:existing_balances) { Employee::Balance.order(:effective_at) }
            let(:options) {{ resource_amount: 1200 }}
            let(:addition) { existing_balances.additions.first }
            let(:addition_removal) { addition.balance_credit_removal }
            let(:balance_id) { addition.id }

            it { expect { subject }.to_not change { Employee::Balance.count } }
            it { expect { subject }.to change { addition.reload.amount }.to 1200 }
            it { expect { subject }.to change { addition_removal.reload.amount } }
            it { expect { subject }.to change { addition.reload.balance } }

            context 'related balances change ' do
              before { subject }

              it { expect(existing_balances.pluck(:being_processed).count(false)).to eq 4 }
              it { expect(existing_balances.pluck(:being_processed).count(true)).to eq 0 }
              it { expect(Employee::Balance.order(:effective_at).map(&:amount))
                .to eq([1200, 2000, -1200, 2000]) }
              it { expect(Employee::Balance.order(:effective_at).pluck(:balance))
                .to eq([1200, 3200, 2000, 4000]) }
            end

            context 'and now it is in the future' do
              let(:options) {{ validity_date: Time.now + 1.year }}

              it { expect { subject }.to change { Employee::Balance.count }.by(-1) }
              it { expect { subject }.to change { Employee::Balance.exists?(addition_removal.id) } }
              it { expect { subject }.to change { addition.reload.validity_date } }
              it { expect { subject }.to_not change { addition.reload.effective_at } }

              context 'related balances change ' do
                before { subject }

                it { expect(existing_balances.pluck(:being_processed).count(false)).to eq 3 }
                it { expect(existing_balances.pluck(:being_processed).count(true)).to eq 0 }
                it { expect(Employee::Balance.order(:effective_at).map(&:amount))
                  .to eq([1000, 2000, 2000]) }
                it { expect(Employee::Balance.order(:effective_at).pluck(:balance))
                  .to eq([1000, 3000, 5000]) }
              end
            end
          end

          context 'and removal is in the future' do
            let(:options) do
              {
                validity_date: Time.zone.now + 1.year + Employee::Balance::REMOVAL_OFFSET,
                resource_amount: 4000
              }
            end
            let(:addition) { existing_balances.additions.last(2).first }
            let(:balance_id) { addition.id }
            context 'and now it is in the past' do
              context 'related balances change' do
                before { subject }

                it { expect(Employee::Balance.order(:effective_at).map(&:amount))
                  .to eq([1000, 4000, -1000, 2000, 100]) }
                it { expect(Employee::Balance.order(:effective_at).pluck(:balance))
                  .to eq([1000, 5000, 4000, 6000, 6100]) }
              end
            end
          end
        end

        context 'with time off' do
          before { allow_any_instance_of(EmployeePresencePolicy).to receive(:valid?) { true } }
          subject { UpdateBalanceJob.perform_now(balance.id, options) }
          let(:pp) { create(:presence_policy, :with_time_entries) }
          let!(:balance) { time_off.employee_balance.tap { |b| b.update!(being_processed: true) } }
          let!(:time_off) do
            create(:time_off,
              start_time: '21 Sep 2015 13:00:00', end_time: '29 Sep 2015 15:00:00',
              time_off_category: category, employee: employee
            )
          end
          let(:epps) do
            ['21/09/2015', '27/09/2015'].map do |date|
              create(:employee_presence_policy, employee: employee, effective_at: date)
            end
          end

          context 'and there are no time entries in time off period' do
            it { expect { subject }.to_not change { balance.reload.amount } }
            it { expect { subject }.to change { balance.reload.being_processed } }
          end

          context 'and there are time entries in time off period' do
            before do
              epps.first.update!(presence_policy: pp)
              create(:presence_day, order: 7, presence_policy: pp)
              create(:presence_day, order: 7, presence_policy: epps.last.presence_policy)
              epps.last.update!(order_of_start_day: 7)
            end

            context 'when only one policy has time entries' do
              it { expect { subject }.to change { balance.reload.resource_amount }.to -240 }
              it { expect { subject }.to change { balance.reload.being_processed } }
              it { expect { subject }.to change { existing_balances.last.reload.being_processed } }
              it { expect { subject }.to_not change { existing_balances.first.reload.being_processed } }
            end

            context 'when two policies have time entries' do
              before { epps.last.update!(presence_policy: pp) }

              it { expect { subject }.to change { balance.reload.resource_amount }.to -1080 }
              it { expect { subject }.to change { balance.reload.being_processed } }
              it { expect { subject }.to change { existing_balances.last.reload.being_processed } }
              it { expect { subject }.to_not change { existing_balances.first.reload.being_processed } }
            end
          end
        end

        context 'without removal and time off' do
          let(:balance_id) { balance.id }
          let(:options) {{ resource_amount: 50 }}

          context 'and there are no employee balances after' do
            it { expect { subject }.to change { balance.reload.resource_amount }.to(50) }
            it { expect { subject }.to change { balance.reload.being_processed }.to false }

            context 'related balances change ' do
              before { subject }

              it { expect(existing_balances.pluck(:being_processed).count(false)).to eq 0 }
            end
          end

          context 'and there are employee balances after' do
            let(:etop_second_effective_at) { 1.year.ago - 1.day }
            let(:balance) do
              employee.employee_balances
                .where(time_off_category: category, policy_credit_addition: true)
                .order(:effective_at).last
            end
            let(:balance_id) { balance.id }

            context 'and its removal is bigger than 0' do
              it { expect { subject }.to change { balance.reload.resource_amount }.to(50) }
              it { expect { subject }.to change { balance.reload.being_processed }.to false }
              it { expect { subject }.to change { existing_balances.last.reload.balance } }
              it { expect { subject }.to_not change { existing_balances.last.reload.resource_amount } }

              context 'related balances change ' do
                before { subject }

                it { expect(existing_balances.pluck(:being_processed).count(false)).to eq 1 }
              end
            end

            context 'and its removal is smaller than 0' do
              context 'and smaller than addition amount' do
                let(:options) { { resource_amount: -100 } }

                it { expect { subject }.to change { balance.reload.resource_amount }.to(-100) }
                it { expect { subject }.to change { balance.reload.being_processed }.to false }
                it { expect { subject }.to change { existing_balances.last.reload.resource_amount }.to(-900) }

                context 'related balances change ' do
                  before { subject }

                  it { expect(existing_balances.pluck(:being_processed).count(false)).to eq 1 }
                end
              end

              context 'and smaller than addition amount' do
                let(:options) { { resource_amount: -1100 } }

                it { expect { subject }.to change { balance.reload.amount }.to(-1100) }
                it { expect { subject }.to change { balance.reload.being_processed }.to false }
                it { expect { subject }.to change { existing_balances.last.reload.balance } }
                it { expect { subject }.to change { existing_balances.last.reload.resource_amount }.to(0) }

                context 'related balances change ' do
                  before { subject }

                  it { expect(existing_balances.pluck(:being_processed).count(false)).to eq 1 }
                end
              end
            end
          end
        end
      end
    end
  end
end
