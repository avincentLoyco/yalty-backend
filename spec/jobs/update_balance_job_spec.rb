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
            shared_examples 'Update of balances being_processed flag' do
              it { expect { subject }.to change { balance.reload.being_processed } }
              it { expect { subject }.to change { previous_removal.reload.being_processed } }
              it { expect { subject }.to change { balance_add.reload.being_processed } }
            end

            context 'amount bigger than policy removal' do
              let(:options) { { effective_at: previous.first + 1.week, amount: -2000} }

              it { expect { subject }.to change { balance.reload.amount }.to(-2000) }
              it { expect { subject }.to change { balance.reload.balance }.to(-1000) }
              it { expect { subject }.to change { previous_removal.reload.amount }.to(0) }

              it { expect { subject }.to change { previous_removal.reload.balance } }
              it { expect { subject }.to change { balance_add.reload.balance } }

              it_behaves_like 'Update of balances being_processed flag'
            end

            context 'amount smaller or equal policy removal' do
              let(:options) { { effective_at: previous.first + 1.week, amount: -300 } }

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
          let(:options) { { amount: -1000 } }

          it { expect { subject }.to change { previous_balance.reload.amount }.to(-1000) }
          it { expect { subject }.to change { previous_balance.reload.balance }.to(0) }
          it { expect { subject }.to change { previous_removal.reload.amount }.to(0) }

          it { expect { subject }.to_not change { balance.reload.being_processed } }
          it { expect { subject }.to_not change { balance_add.reload.being_processed } }
          it { expect { subject }.to_not change { balance_add.reload.balance } }

          it_behaves_like 'Update of previous period balances params'
        end

        context 'amount greater than policy removal' do
          let(:options) { { amount: -2000 } }

          it { expect { subject }.to change { previous_balance.reload.amount }.to(-2000) }
          it { expect { subject }.to change { previous_balance.reload.balance }.to(-1000) }
          it { expect { subject }.to change { previous_removal.reload.amount }.to(0) }

          it_behaves_like 'Update of previous period balances params'
          it_behaves_like 'Update of current period balances params'
        end

        context 'amount is addition' do
          let(:options) { { amount: 2000 } }

          it { expect { subject }.to change { previous_balance.reload.amount }.to(2000) }
          it { expect { subject }.to change { previous_balance.reload.balance }.to(3000) }
          it { expect { subject }.to change { previous_removal.reload.amount }.to(-1000) }

          it_behaves_like 'Update of previous period balances params'
          it_behaves_like 'Update of current period balances params'
        end

        context 'and now in current period' do
          let(:options) { { amount: -500, effective_at: current.last - 2.weeks } }

          it { expect { subject }.to change { previous_balance.reload.effective_at } }
          it { expect { subject }.to change { previous_balance.reload.balance }.to(500) }
          it { expect { subject }.to change { previous_removal.reload.amount }.to(-1000) }
          it { expect { subject }.to change { balance.reload.balance }.to(0) }

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
        let(:options) { { amount: 500 } }

        it { expect { subject }.to_not change { balance_add.reload.being_processed } }
        it { expect { subject }.to_not change { previous_balance.reload.being_processed } }

        it_behaves_like 'Update of current period balances'

        context 'and now in previous' do
          let(:options) { { effective_at: previous.first + 2.days, amount: 500 } }

          it { expect { subject }.to change { previous_balance.reload.balance } }
          it { expect { subject }.to change { balance_add.reload.balance } }

          it_behaves_like 'Update of current period balances'
        end
      end

      context 'balance in previous policy' do
        let(:balance_id) { previous_balance.id }
        let(:options) { {  amount: -100 } }

        it_behaves_like 'Update of previous period balances'

        context 'and now in current' do
          let(:options) {{ amount: -100, effective_at: current.last }}

          it_behaves_like 'Update of previous period balances'
        end
      end
    end

    context 'when emplyee has few time off policies, working places, holidays, presence policies' do
      before do
        allow_any_instance_of(EmployeeTimeOffPolicy).to receive(:valid?) { true }
        employee.first_employee_event.update!(effective_at: Time.now - 4.years)
        ewp_first.update!(effective_at: Time.now - 4.years, working_place: wps.first)
        ManageEmployeeBalanceAdditions.new(etops.first).call
        ManageEmployeeBalanceAdditions.new(etops.second).call
        Employee::Balance.update_all(being_processed: true)
      end

      let(:category) { create(:time_off_category, account: account) }
      let(:existing_balances) { Employee::Balance.where.not(id: balance.id).order(:effective_at) }
      let(:top_first) do
        create(:time_off_policy, :with_end_date, time_off_category: category, amount: 1000)
      end
      let(:top_second) { create(:time_off_policy, time_off_category: category, amount: 2000) }
      let(:ewp_first) { employee.first_employee_working_place }
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
      let!(:etops) do
        [[top_first, Time.now - 2.years], [top_second, Time.now - 1.year]].map do |top, date|
          create(:employee_time_off_policy,
            employee: employee, time_off_policy: top, effective_at: date)
        end.flatten
      end

      context 'when employee balance is updated' do
        subject { UpdateBalanceJob.perform_now(balance_id, options) }
        let(:effective_at) { Time.now + 1.day }
        let!(:balance) do
          create(:employee_balance,
            employee: employee, effective_at: effective_at, time_off_category: category,
            being_processed: true, amount: 100
          )
        end

        let(:balance_id) { balance.id }
        let(:options) {{ amount: 50 }}

        it 'has proper employee balances effective_at in database' do
          expect(existing_balances.pluck(:effective_at).map(&:to_date)).to eql(
            ['1/1/2014', '1/1/2015', '1/4/2015', '1/1/2016'].map(&:to_date)
          )
        end

        it { expect(existing_balances.pluck(:amount)).to eql([1000, 2000, -1000, 2000]) }

        context 'with removal' do
          context 'and removal is in the past' do
            let(:options) do
              {
                effective_at: Time.now - 1.year - 2.days,
                validity_date: Time.now - 3.days,
                amount: 1200
              }
            end
            let(:addition) { existing_balances.additions.first }
            let(:addition_removal) { addition.balance_credit_removal }
            let(:balance_id) { addition.id }

            it { expect { subject }.to_not change { Employee::Balance.count } }

            it { expect { subject }.to change { addition.reload.amount }.to 1200 }
            it { expect { subject }.to change { addition.reload.validity_date } }
            it { expect { subject }.to change { addition.reload.effective_at } }
            it { expect { subject }.to change { addition_removal.reload.amount } }
            it { expect { subject }.to change { addition_removal.reload.effective_at } }
            it { expect { subject }.to change { addition.reload.balance } }

            context 'related balances change ' do
              before { subject }

              it { expect(existing_balances.pluck(:being_processed).count(false)).to eq 4 }
              it { expect(existing_balances.pluck(:being_processed).count(true)).to eq 0 }
              it { expect(addition_removal.effective_at).to eq(Time.now - 3.days) }

              it { expect(Employee::Balance.order(:effective_at).pluck(:amount))
                .to eq([1200, 2000, -1200, 2000, 100]) }
              it { expect(Employee::Balance.order(:effective_at).pluck(:balance))
                .to eq([1200, 3200, 2000, 4000, 4100]) }
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

                it { expect(Employee::Balance.order(:effective_at).pluck(:amount))
                  .to eq([1000, 2000, 2000, 100]) }
                it { expect(Employee::Balance.order(:effective_at).pluck(:balance))
                  .to eq([1000, 3000, 5000, 5100]) }
              end
            end
          end

          context 'and removal is in the future' do
            let(:options) {{ validity_date: Time.now - 2.days, amount: 4000 }}
            let(:addition) { existing_balances.additions.last(2).first }
            let(:balance_id) { addition.id }

            context 'and now it is in the past' do
              it { expect { subject }.to change { Employee::Balance.count }.by(1) }
              it { expect { subject }.to change { addition.reload.validity_date } }
              it { expect { subject }.to_not change { addition.reload.effective_at } }

              context 'related balances change' do
                before { subject }

                it { expect(existing_balances.pluck(:being_processed).count(false)).to eq 4 }
                it { expect(existing_balances.pluck(:being_processed).count(true)).to eq 1 }
                it { expect(Employee::Balance.order(:effective_at).pluck(:amount))
                  .to eq([1000, 4000, -1000, -4000, 2000, 100]) }
                it { expect(Employee::Balance.order(:effective_at).pluck(:balance))
                  .to eq([1000, 5000, 4000, 0, 2000, 2100]) }
              end
            end
          end
        end

        context 'with time off' do
          before { allow_any_instance_of(EmployeePresencePolicy).to receive(:valid?) { true } }
          subject { UpdateBalanceJob.perform_now(balance.id, options) }
          let(:pp) { create(:presence_policy, :with_time_entries) }
          let(:balance) do
            time_off.employee_balance.tap { |balance| balance.update!(being_processed: true) }
          end
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
            it { expect { subject }.to change { balance.reload.amount }.to 0 }
            it { expect { subject }.to change { balance.reload.being_processed } }
          end

          context 'and there are time entries in time off period' do
            before { epps.first.update!(presence_policy: pp) }

            context 'when only one policy has time entries' do
              it { expect { subject }.to change { balance.reload.amount }.to -240 }
              it { expect { subject }.to change { balance.reload.being_processed } }
              it { expect { subject }.to change { existing_balances.last.reload.being_processed } }
              it { expect { subject }.to_not change { existing_balances.first.reload.being_processed } }
            end

            context 'when two policies have time entries' do
              before { epps.last.update!(presence_policy: pp) }

              it { expect { subject }.to change { balance.reload.amount }.to -1080 }
              it { expect { subject }.to change { balance.reload.being_processed } }
              it { expect { subject }.to change { existing_balances.last.reload.being_processed } }
              it { expect { subject }.to_not change { existing_balances.first.reload.being_processed } }
            end
          end
        end

        context 'without removal and time off' do
          context 'and there are no employee balances after' do
            it { expect { subject }.to change { balance.reload.amount }.to(50) }
            it { expect { subject }.to change { balance.reload.being_processed }.to false }

            context 'related balances change ' do
              before { subject }

              it { expect(existing_balances.pluck(:being_processed).count(false)).to eq 0 }
            end
          end

          context 'and there are employee balances after' do
            let(:effective_at) { Time.now - 10.months }

            context 'and its removal is bigger than 0' do
              it { expect { subject }.to change { balance.reload.amount }.to(50) }
              it { expect { subject }.to change { balance.reload.being_processed }.to false }
              it { expect { subject }.to change { existing_balances.last(2).first.reload.balance } }
              it { expect { subject }.to change { existing_balances.last.reload.balance } }

              it { expect { subject }.to_not change { existing_balances.last(2).first.reload.amount } }
              it { expect { subject }.to_not change { existing_balances.last.reload.amount } }

              context 'related balances change ' do
                before { subject }

                it { expect(existing_balances.pluck(:being_processed).count(false)).to eq 2 }
              end
            end

            context 'and its removal is smaller than 0' do
              context 'and smaller than addition amount' do
                let(:options) { { amount: -100 } }

                it { expect { subject }.to change { balance.reload.amount }.to(-100) }
                it { expect { subject }.to change { balance.reload.being_processed }.to false }
                it { expect { subject }.to change { existing_balances.last(2).first.reload.balance } }
                it { expect { subject }.to change { existing_balances.last(2).first.reload.amount }.to(-900) }
                it { expect { subject }.to_not change { existing_balances.last.reload.balance } }
                it { expect { subject }.to_not change { existing_balances.last.reload.amount } }

                context 'related balances change ' do
                  before { subject }

                  it { expect(existing_balances.pluck(:being_processed).count(false)).to eq 1 }
                end
              end

              context 'and smaller than addition amount' do
                let(:options) { { amount: -1100 } }

                it { expect { subject }.to change { balance.reload.amount }.to(-1100) }
                it { expect { subject }.to change { balance.reload.being_processed }.to false }
                it { expect { subject }.to change { existing_balances.last(2).first.reload.balance } }
                it { expect { subject }.to change { existing_balances.last(2).first.reload.amount }.to(0) }
                it { expect { subject }.to change { existing_balances.last.reload.balance } }
                it { expect { subject }.to_not change { existing_balances.last.reload.amount } }

                context 'related balances change ' do
                  before { subject }

                  it { expect(existing_balances.pluck(:being_processed).count(false)).to eq 2 }
                end
              end
            end
          end
        end
      end
    end
  end
end
