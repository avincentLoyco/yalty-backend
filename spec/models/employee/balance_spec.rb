require 'rails_helper'

RSpec.describe Employee::Balance, type: :model do
  include_context 'shared_context_timecop_helper'
  it { is_expected.to have_db_column(:id).of_type(:uuid) }
  it { is_expected.to have_db_column(:balance).of_type(:integer).with_options(default: 0) }
  it { is_expected.to have_db_column(:employee_id).of_type(:uuid).with_options(null: false) }
  it { is_expected.to have_db_column(:time_off_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:time_off_category_id)
    .of_type(:uuid).with_options(null: false) }
  it { is_expected.to have_db_column(:validity_date).of_type(:datetime) }
  it { is_expected.to have_db_column(:balance_credit_removal_id).of_type(:uuid) }

  it { is_expected.to have_db_index(:time_off_id) }
  it { is_expected.to have_db_index(:time_off_category_id) }
  it { is_expected.to have_db_index(:employee_id) }
  it { is_expected.to have_db_index(:balance_credit_removal_id) }

  it { is_expected.to validate_presence_of(:employee) }
  it { is_expected.to validate_presence_of(:time_off_category) }
  it { is_expected.to validate_presence_of(:balance) }

  context 'callbacks and helper methods' do
    let(:account) { create(:account) }
    let(:time_off_category) { create(:time_off_category, account: account) }
    let(:balance) { build(:employee_balance, resource_amount: 200, time_off_category: time_off_category, employee: employee) }
    let(:policy) { create(:time_off_policy, time_off_category: time_off_category) }
    let(:employee) { create(:employee, account: account) }
    let!(:employee_policy) do
      create(:employee_time_off_policy,
        employee: employee, time_off_policy: policy, effective_at: Date.today - 6.years
      )
    end
    subject { balance }

    context 'callbacks' do
      include_context 'shared_context_timecop_helper'

      context 'balance calculation' do
        context 'when balance is the first in category' do
          it { expect { subject.valid? }.to change { subject.balance }.to(200) }
        end

        context 'when balances before already exist in the category' do
          before do
            create(:employee_balance,
              resource_amount: 100, employee: employee, time_off_category: time_off_category
            )
          end

          context 'and belongs to other employee' do
            let(:balance) { build(:employee_balance, resource_amount: 200) }
            it { expect { subject.valid? }.to change { subject.balance }.to(200) }
          end

          context 'and belong to current balance employee' do
            it { expect { subject.valid? }.to change { subject.balance }.to(300) }
          end
        end
      end

      context 'effective at set up' do
        context 'when effective at nil' do
          let(:balance) { build(:employee_balance_manual) }
          it { expect { subject.valid? }.to change { subject.effective_at }.to be_kind_of(Time) }
        end

         context 'when balance is removal' do
          before { balance.balance_credit_additions << addition }
          let(:addition) do
            create(:employee_balance,
              time_off_category: time_off_category,
              validity_date: Time.now + 1.week
            )
          end

          it { expect { subject.valid? }.to change { subject.effective_at } }

          context 'removal effective at equals addition validity date' do
            before { subject.valid? }

            it { expect(subject.effective_at.to_date).to eq addition.validity_date.to_date }
          end
        end

        context 'when effective at already set' do
          subject { build(:employee_balance, resource_amount: 200, effective_at: Time.now - 1.week) }

          it { expect { subject.valid? }.to_not change { subject.effective_at } }
        end

        context 'when employee balance has time off' do
          let(:time_off) { create(:time_off, employee: employee, start_time: Date.today - 1.week, time_off_category: time_off_category ) }
          subject { build(:employee_balance, time_off: time_off) }

          it { expect { subject.valid? }.to change { subject.effective_at } }

          context 'effective_at date value' do
            before { subject.valid? }

            it { expect(subject.effective_at).to eq time_off.end_time }
          end
        end
      end
    end

    context 'validations' do

      context 'effective_after_employee_creation' do

        context 'when effective at before employee creation' do
          let(:effective_at) { Time.now - 11.years }
          let(:employee) { create(:employee) }
          let(:balance) { build(:employee_balance_manual, employee: employee, effective_at: effective_at) }
          subject { balance }

          it { expect(subject.valid?).to eq false }
          it { expect { subject.valid? }.to change { subject.errors.messages[:effective_at] }
            .to include('Can not be added before employee start date') }
        end

        context 'when effective at after employee creation' do
          let(:effective_at) { Time.now - 2.years }

          it { expect(subject.valid?).to eq true }
          it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }
        end
      end

      context 'validity date presence' do
        subject { balance.valid? }

        context 'when employee balance has removal' do
          before { balance.balance_credit_removal = create(:employee_balance) }

          it { expect(subject).to eq false }
          it { expect { subject }.to change { balance.errors.messages.count }.by(1) }
        end

        context 'when employee balance does not have removal' do
          it { expect(subject).to eq true }
          it { expect { subject }.to_not change { balance.errors.messages.count } }
        end
      end

      context 'time_off_policy_presence' do
        context 'when employee has active time off policy' do
          it { expect(subject.valid?).to eq true }
          it { expect { subject.valid? }.to_not change { subject.errors.messages } }
        end

        context 'when employee does not have active policy' do
          let(:balance) { build(:employee_balance_manual) }
          it { expect { subject.valid? }.to change { subject.errors.messages[:employee] }
            .to include('Must have an associated time off policy in the balance category') }
        end
      end

      context 'counter validity date blank' do
        before { policy.update!(policy_type: 'counter', amount: nil) }

        context 'when validity date is nil' do
          it { expect(subject.valid?).to eq true }
          it { expect { subject.valid? }.to_not change { balance.errors.size } }
        end

        context 'when validity date is present' do
          before { balance.validity_date = Date.today }

          context 'and policy is a counter type' do
            it { expect(subject.valid?).to eq false }
            it { expect { subject.valid? }.to change { balance.errors.size } }
          end

          context 'and policy is a balancer type' do
            before do
              policy.update!(policy_type: 'balancer', amount: 100)
              balance.effective_at = Date.today - 1.year
            end

            it { expect(subject.valid?).to eq true }
            it { expect { subject.valid? }.to_not change { balance.errors.size } }
          end
        end
      end

      context 'effective_at_equal_time_off_end_date' do
        subject do
          build(:employee_balance, :with_time_off, employee: employee,
            time_off_category: time_off_category )
        end

        it { expect(subject.valid?).to eq true }
        it { expect { subject.valid? }.to_not change { subject.errors.size } }

      end
      context 'effective_at_equal_time_off_policy_dates' do

        context 'with valid params when the effective at' do
          context ' matches the assignation date of the ETOP' do
            let(:effective_at) { employee_policy.effective_at }


            it { expect(subject.valid?).to eq true }
            it { expect { subject.valid? }.to_not change { subject.errors.size } }
          end

          context ' matches the day before the TOP start date' do

            let(:effective_at) do
              top = employee_policy.time_off_policy
              Date.new(Time.now.year, top.start_month, top.start_day) - 1.day
            end

            it { expect(subject.valid?).to eq true }
            it { expect { subject.valid? }.to_not change { subject.errors.size } }
          end

          context ' matches the TOP start date' do

            let(:effective_at) do
              top = employee_policy.time_off_policy
              Date.new(Time.now.year, top.start_month, top.start_day)
            end

            it { expect(subject.valid?).to eq true }
            it { expect { subject.valid? }.to_not change { subject.errors.size } }
          end

          context ' matches the TOP end date' do

            let(:policy) { create(:time_off_policy, :with_end_date) }

            let(:effective_at) do
              Date.new(Time.now.year, policy.end_month, policy.end_day)
            end

            it { expect(subject.valid?).to eq true }
            it { expect { subject.valid? }.to_not change { subject.errors.size } }
          end
        end

        context 'with invalid params' do
          let(:balance) { build(:employee_balance_manual, employee: employee,  effective_at: effective_at, time_off_category: time_off_category)}

          context 'when the employee has a an employee time off policy in valid range of the balance' do

            let(:effective_at) { Time.now - 1.month }

            it { expect(subject.valid?).to eq false }
            it { expect { subject.valid? }.to change { subject.errors.messages[:effective_at] }
              .to include 'Must be at TimeOffPolicy  assignations date, end date, start date'\
              ' or the previous day to start date' }
          end
        end
      end

      context 'removal effective at date' do
        subject { balance }

        before do
          allow_any_instance_of(Employee::Balance).to receive(:find_effective_at) { true }
          balance.balance_credit_additions << balance_addition
          balance.effective_at = Date.today
        end

        let!(:balance_addition) do
          create(:employee_balance,
            validity_date: Date.today,
            effective_at: Date.today - 1.week,
            time_off_category: time_off_category,
          )
        end

        context 'when removal effective_at valid' do
          it { expect { subject.valid? }.to_not change { balance.errors.size } }
          it { expect(subject.valid?).to eq true }
        end

        context 'when removal effective at not valid' do
          before { balance.effective_at = Date.today - 1.month }

          it { expect(subject.valid?).to eq false }
          it { expect { subject.valid? }.to change { balance.errors.size } }
          it { expect { subject.valid? }.to change { balance.errors.messages[:effective_at] }
            .to include('Removal effective at must equal addition validity date') }
        end
      end
    end

    context 'related_amount' do
      let(:time_off_start) { Time.zone.parse('01/01/2015') }
      let(:time_off_end) { Time.zone.parse('10/01/2015') }
      let(:top_start_day) { 7 }
      let(:top_balance_effective_at) { Time.zone.parse('07/01/2015') }
      let(:etop_effective_at) { Time.zone.parse('05/01/2015') }

      let(:pp) do
        create(:presence_policy, :with_time_entries,
          number_of_days: 7,
          working_days: [1, 2, 3, 4, 5],
          hours: [%w(08:00 12:00), %w(13:00 17:00)]
        )
      end

      let!(:epp) do
        create(:employee_presence_policy,
          presence_policy: pp,
          employee: employee,
          effective_at: 1.year.ago,
          order_of_start_day: 1.year.ago.to_date.cwday
        )
      end

      let(:policy) do
        create(:time_off_policy, :with_end_date, time_off_category: time_off_category,
          start_day: top_start_day)
      end

      let!(:etop) do
        create(:employee_time_off_policy, employee: employee, time_off_policy: policy,
          effective_at: etop_effective_at)
      end

      let!(:etop_balance) do
        create(:employee_balance_manual, employee: employee, time_off_category: time_off_category,
          effective_at: etop.effective_at, policy_credit_addition: false)
      end

      let!(:top_start_balance) do
        create(:employee_balance_manual, employee: employee, time_off_category: time_off_category,
          effective_at: top_balance_effective_at, policy_credit_addition: true)
      end

      let(:time_off) do
        create(:time_off, employee: employee, time_off_category: time_off_category,
          start_time: time_off_start, end_time: time_off_end)
      end

      let(:time_off_balance) { time_off.employee_balance }

      before { Timecop.freeze('15/01/2015') }
      after { Timecop.return }

      context 'presence policy does not change' do
        before { time_off }

        context 'time off overlaps TOP start date' do
          let(:etop_effective_at) { Time.zone.parse('01/01/2014') }

          it { expect(top_start_balance.related_amount).to eq(-2400) }
          it { expect(time_off_balance.related_amount).to eq(2400) }
        end

        context 'time off overlaps TOP start date and ETOP assignation' do
          it { expect(etop_balance.related_amount).to eq(-1440) }
          it { expect(top_start_balance.related_amount).to eq(-960) }
          it { expect(time_off_balance.related_amount).to eq(2400) }
        end

        context 'ETOP assignation is on time_off start_time' do
          let(:etop_effective_at) { time_off_start }
          let(:top_start_day) { 15 }
          let(:top_balance_effective_at) { time_off_end + 5.days }

          it { expect(etop_balance.related_amount).to eq(-480) }
          it { expect(time_off_balance.related_amount).to eq(480) }
        end

        context 'time_off starts middle of day' do
          let(:etop_effective_at) { Time.zone.parse('01/01/2014') }
          before { time_off.update!(start_time: time_off_start + 13.hours) }

          it { expect(top_start_balance.related_amount).to eq(-2160) }
          it { expect(time_off_balance.related_amount).to eq(2160) }
        end
      end

      context 'presence policy changes during time_off' do
        let(:half_time_pp) do
          create(:presence_policy, :with_time_entries,
            number_of_days: 7,
            working_days: [1, 2, 3, 4, 5],
            hours: [%w(08:00 12:00)]
          )
        end

        let!(:half_time_epp) do
          create(:employee_presence_policy,
            presence_policy: half_time_pp,
            employee: employee,
            effective_at: etop_effective_at,
            order_of_start_day: etop_effective_at.to_date.cwday
          )
        end

        before { time_off }

        it { expect(etop_balance.related_amount).to eq(-1200) }
        it { expect(top_start_balance.related_amount).to eq(-480) }
        it { expect(time_off_balance.related_amount).to eq(1680) }
      end

      context 'different category' do
        let(:diff_category) { create(:time_off_category, account: account,  name: 'cat2') }

        let!(:diff_category_policy) do
          create(:time_off_policy, :with_end_date, time_off_category: diff_category, start_day: 4)
        end

        let(:diff_top_start_balance) do
          create(:employee_balance, employee: employee, time_off_category: diff_category,
            effective_at: top_balance_effective_at, policy_credit_addition: true)
        end

        it { expect(diff_top_start_balance.related_amount).to eq(0) }
      end
    end
  end
end
