require "rails_helper"

RSpec.describe Employee::Balance, type: :model do
  include_context "shared_context_timecop_helper"
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

  context "callbacks and helper methods" do
    let(:account) { create(:account) }
    let(:time_off_category) { create(:time_off_category, account: account) }
    let(:balance) do
       build(:employee_balance,
        resource_amount: 200, time_off_category: time_off_category, employee: employee)
    end
    let(:policy) { create(:time_off_policy, time_off_category: time_off_category) }
    let(:employee) { create(:employee, account: account) }
    let!(:employee_policy) do
      create(:employee_time_off_policy,
        employee: employee, time_off_policy: policy, effective_at: Date.today - 6.years
      )
    end
    subject { balance }

    context "callbacks" do
      include_context "shared_context_timecop_helper"

      context "balance calculation" do
        context "when balance is the first in category" do
          it { expect { subject.valid? }.to change { subject.balance }.to(200) }
        end

        context "when balances before already exist in the category" do
          before do
            create(:employee_balance,
              resource_amount: 100, employee: employee, time_off_category: time_off_category
            )
          end

          context "and belongs to other employee" do
            let(:balance) { build(:employee_balance, resource_amount: 200) }
            it { expect { subject.valid? }.to change { subject.balance }.to(200) }
          end

          context "and belong to current balance employee" do
            it { expect { subject.valid? }.to change { subject.balance }.to(300) }
          end
        end
      end

      context "effective at set up" do
        context "when effective at nil" do
          let(:balance) { build(:employee_balance_manual) }
          it { expect { subject.valid? }.to change { subject.effective_at }.to be_kind_of(Time) }
        end

         context "when balance is removal" do
          before do
            balance.effective_at = nil
            balance.balance_credit_additions << addition
          end

          let(:addition) do
            create(:employee_balance,
              time_off_category: time_off_category,
              validity_date: Time.now + 1.week
            )
          end

          it { expect { subject.valid? }.to change { subject.effective_at } }

          context "removal effective at equals addition validity date" do
            before { subject.valid? }

            it { expect(subject.effective_at.to_date).to eq addition.validity_date.to_date }
          end
        end

        context "when effective at already set" do
          subject { build(:employee_balance, resource_amount: 200, effective_at: Time.now - 1.week) }

          it { expect { subject.valid? }.to_not change { subject.effective_at } }
        end

        context "when employee balance has time off" do
          let(:time_off) do
            create(:time_off,
              employee: employee, start_time: Date.today - 1.week,
              time_off_category: time_off_category)
          end
          subject { build(:employee_balance, time_off: time_off) }

          it { expect { subject.valid? }.to change { subject.effective_at } }

          context "effective_at date value" do
            before { subject.valid? }

            it { expect(subject.effective_at).to eq time_off.end_time }
          end
        end
      end
    end

    context "validations" do
      context "#reset_effective_at_after_contract_end" do
        let!(:contract_end) do
          create(:employee_event,
            employee: employee, effective_at: Date.new(2014, 1, 1), event_type: "contract_end"
          ).effective_at
        end

        subject { employee.reload.employee_balances.first  }

        before { employee.events.reload }

        context "with valid params" do
          let(:effective_at) { contract_end + 1.day + Employee::Balance::RESET_OFFSET }

          it { expect(subject.update(effective_at: effective_at)).to eq true }
        end

        context "with invalid params" do
          context "effective at before contract end" do
            let(:effective_at) { contract_end - 1.day }

            it { expect(subject.update(effective_at: effective_at)).to eq false }
            it do
              expect { subject.update(effective_at: effective_at) }
                .to change { subject.errors.messages[:effective_at] }
                .to include "Reset Balance effective at must be at contract end"
            end
          end

          context "effective at after contract end but without valid effective at" do
            let(:effective_at) { contract_end - 1.second }

            it { expect(subject.update(effective_at: effective_at)).to eq false }
            it do
              expect { subject.update(effective_at: effective_at) }
                .to change { subject.errors.messages[:effective_at] }
                .to include "Reset Balance effective at must be at contract end"
            end
          end
        end
      end

      context "end_time_not_after_contract_end" do
        before do
          create(:employee_event,
            employee: employee, effective_at: Date.new(2014, 1, 1), event_type: "contract_end"
          )
          employee.events.reload
        end
        subject do
          build(:employee_balance_manual,
            employee: employee, time_off_category: time_off_category, effective_at: effective_at,
            balance_type: "addition")
        end

        context "when employee has one contract end date" do
          context "with valid data" do
            let(:effective_at) { Date.new(2013, 1, 1) }

            it { expect(subject.valid?).to eq true }
            it { expect { subject.valid? }.to_not change { subject.errors.messages } }
          end

          context "with invalid data" do
            let(:effective_at) { Date.new(2014, 1, 2) + 1.day + 1.second }

            it { expect(subject.valid?).to eq false }
            it do
              expect { subject.valid? }.to change { subject.errors.messages[:effective_at] }
                .to include "can't be set outside of employee contract period"
            end
          end

          context "for time offs" do
            let(:end_time) { (employee.contract_end_for(Date.today) + 1.day).beginning_of_day }
            let(:time_off) do
              create(:time_off,
                employee: employee,
                time_off_category: time_off_category,
                start_time: end_time - 1.day,
                end_time: end_time
              ) do |time_off|
                TimeOffs::Approve.call(time_off)
              end
            end

            subject { time_off.reload.employee_balance }

            context "with valid effective_at" do
              it { expect(subject).to be_valid }
              it { expect { subject.valid? }.to_not change { subject.errors.messages.size } }
            end
          end
        end

        context "when employee has more than one contract end date" do
          before do
            create(:employee_event,
              employee: employee, effective_at: Date.new(2015, 1, 1), event_type: "hired"
            )
            create(:employee_event,
              employee: employee, effective_at: Date.new(2016, 1, 1), event_type: "contract_end"
            )
            employee.events.reload
          end

          context "with valid data" do
            before { subject.balance_type = "time_off" }
            let(:effective_at) { Date.new(2015, 1, 1) }

            it { expect(subject.valid?).to eq true }
            it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }
          end

          context "with invalid data" do
            context "effective_at between old contract end and new contract end" do
              let(:effective_at) { Date.new(2014, 1, 1) + 1.day + 3.seconds }

              it { expect(subject.valid?).to eq false }
              it do
                expect { subject.valid? }.to change { subject.errors.messages[:effective_at] }
                  .to include "can't be set outside of employee contract period"
              end
            end

            context "effective at after new contract end" do
              let(:effective_at) { Date.new(2016, 1, 1) + 1.day + 3.seconds  }

              it { expect(subject.valid?).to eq false }
              it do
                expect { subject.valid? }.to change { subject.errors.messages[:effective_at] }
                  .to include "can't be set outside of employee contract period"
              end
            end
          end
        end
      end

      context "effective_after_employee_creation" do
        context "when effective at before employee creation" do
          let(:effective_at) { Time.now - 11.years }
          let(:employee) { create(:employee) }
          let(:balance) { build(:employee_balance_manual, employee: employee, effective_at: effective_at) }
          subject { balance }

          it { expect(subject.valid?).to eq false }
          it { expect { subject.valid? }.to change { subject.errors.messages[:effective_at] }
            .to include("can't be set outside of employee contract period") }
        end

        context "when effective at after employee creation" do
          let(:effective_at) { Time.now - 2.years }

          it { expect(subject.valid?).to eq true }
          it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }
        end
      end

      xcontext "validity date presence" do
        subject { balance.valid? }

        context "when employee balance has removal" do
          before { balance.balance_credit_removal = create(:employee_balance) }

          it { expect(subject).to eq false }
          it { expect { subject }.to change { balance.errors.messages.count }.by(1) }
        end

        context "when employee balance does not have removal" do
          it { expect(subject).to eq true }
          it { expect { subject }.to_not change { balance.errors.messages.count } }
        end
      end

      context "time_off_policy_presence" do
        context "when employee has active time off policy" do
          it { expect(subject.valid?).to eq true }
          it { expect { subject.valid? }.to_not change { subject.errors.messages } }
        end

        context "when employee does not have active policy" do
          let(:balance) { build(:employee_balance_manual) }
          it { expect { subject.valid? }.to change { subject.errors.messages[:employee] }
            .to include("Must have an associated time off policy in the balance category") }
        end
      end

      context "counter validity date blank" do
        before { policy.update!(policy_type: "counter", amount: 0) }

        context "when validity date is nil" do
          it { expect(subject.valid?).to eq true }
          it { expect { subject.valid? }.to_not change { balance.errors.size } }
        end

        context "when validity date is present" do
          before { balance.validity_date = Date.today }

          context "and policy is a counter type" do
            it { expect(subject.valid?).to eq false }
            it { expect { subject.valid? }.to change { balance.errors.size } }
          end

          context "and policy is a balancer type" do
            before do
              policy.update!(policy_type: "balancer", amount: 100)
              balance.effective_at = Date.today - 1.year
            end

            it { expect(subject.valid?).to eq true }
            it { expect { subject.valid? }.to_not change { balance.errors.size } }
          end
        end
      end

      context "effective_at_equal_time_off_end_date" do
        subject do
          build(:employee_balance, :with_time_off, employee: employee,
            time_off_category: time_off_category )
        end

        it { expect(subject.valid?).to eq true }
        it { expect { subject.valid? }.to_not change { subject.errors.size } }
      end

      context "effective_at_equal_time_off_policy_dates" do
        context "with valid params when the effective at" do
          context " matches the assignation date of the ETOP" do
            let(:effective_at) { employee_policy.effective_at }


            it { expect(subject.valid?).to eq true }
            it { expect { subject.valid? }.to_not change { subject.errors.size } }
          end

          context " matches the day before the TOP start date" do

            let(:effective_at) do
              top = employee_policy.time_off_policy
              Date.new(Time.now.year, top.start_month, top.start_day) - 1.day
            end

            it { expect(subject.valid?).to eq true }
            it { expect { subject.valid? }.to_not change { subject.errors.size } }
          end

          context " matches the TOP start date" do

            let(:effective_at) do
              top = employee_policy.time_off_policy
              Date.new(Time.now.year, top.start_month, top.start_day)
            end

            it { expect(subject.valid?).to eq true }
            it { expect { subject.valid? }.to_not change { subject.errors.size } }
          end

          context " matches the TOP end date" do
            let(:policy) { create(:time_off_policy, :with_end_date) }

            let(:effective_at) do
              Date.new(Time.now.year, policy.end_month, policy.end_day)
            end

            it { expect(subject.valid?).to eq true }
            it { expect { subject.valid? }.to_not change { subject.errors.size } }
          end
        end

        context "with invalid params" do
          let(:balance) do
            build(:employee_balance_manual,
              employee: employee,  effective_at: effective_at, time_off_category: time_off_category
            )
          end

          context "when the employee has a an employee time off policy in valid range of the balance" do

            let(:effective_at) { Time.now - 1.month }

            it { expect(subject.valid?).to eq false }
            it { expect { subject.valid? }.to change { subject.errors.messages[:effective_at] }
              .to include "Must be at TimeOffPolicy assignations date, end date, start date"\
              " or the previous day to start date" }
          end
        end
      end

      context "removal effective at date" do
        subject { balance }

        before do
          allow_any_instance_of(Employee::Balance).to receive(:find_effective_at) { true }
          balance.balance_credit_additions << balance_addition
          balance.balance_type = "removal"
          balance.effective_at = Date.today
        end

        let!(:balance_addition) do
          create(:employee_balance,
            validity_date: Date.today,
            effective_at: Date.today - 1.week,
            time_off_category: time_off_category,
          )
        end

        context "when removal effective_at valid" do
          it { expect { subject.valid? }.to_not change { balance.errors.size } }
          it { expect(subject.valid?).to eq true }
        end

        context "when removal effective at not valid" do
          before { balance.effective_at = Date.today - 1.month }

          it { expect(subject.valid?).to eq false }
          it { expect { subject.valid? }.to change { balance.errors.size } }
          it { expect { subject.valid? }.to change { balance.errors.messages[:effective_at] }
            .to include("Removal effective at must equal addition validity date and period") }
        end
      end
    end

    context "related_amount" do
      let(:time_off_start) { Time.zone.parse("01/01/2015") }
      let(:time_off_end) { Time.zone.parse("10/01/2015") }
      let(:top_start_day) { 7 }
      let(:top_end_day) { 8 }
      let(:top_balance_effective_at) { Time.zone.parse("07/01/2015") }
      let(:etop_effective_at) { Time.zone.parse("05/01/2015") }
      let(:end_balance_effective_at) { Time.zone.parse("09.01.2015") }

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
        create(:time_off_policy, time_off_category: time_off_category,
          start_day: top_start_day, amount: 4800,
          end_day: top_end_day, end_month: 1, years_to_effect: 1)
      end

      let!(:etop) do
        create(:employee_time_off_policy, employee: employee, time_off_policy: policy,
          effective_at: etop_effective_at)
      end

      let!(:etop_balance) do
        create(:employee_balance_manual, employee: employee, time_off_category: time_off_category,
          effective_at: etop.effective_at + Employee::Balance::ASSIGNATION_OFFSET,
          balance_type: "assignation", resource_amount: 4800,
          validity_date: Date.new(2015, 1, 9) + Employee::Balance::REMOVAL_OFFSET)
      end

      let!(:top_start_balance) do
        create(:employee_balance_manual, employee: employee, time_off_category: time_off_category,
          effective_at: top_balance_effective_at + Employee::Balance::ADDITION_OFFSET,
          balance_type: "addition", resource_amount: 4800)
      end
      let(:top_end_balance) do
        create(:employee_balance_manual, employee: employee, time_off_category: time_off_category,
          effective_at: etop_balance.validity_date,
          balance_type: "removal", balance_credit_additions: [etop_balance])
      end

      let(:time_off) do
        create(:time_off,
          employee: employee,
          time_off_category: time_off_category,
          start_time: time_off_start,
          end_time: time_off_end
        ) do |time_off|
          TimeOffs::Approve.call(time_off)
          time_off.reload
        end
      end

      let(:time_off_balance) do
        time_off.employee_balance
      end

      around(:each) do |example|
        travel_to Date.new(2015, 1, 15) do
          example.run
        end
      end

      context "presence policy does not change" do
        let(:time_off_amount) { time_off.balance }

        context "time off overlaps TOP start date" do
          let(:etop_effective_at) { Time.zone.parse("07/01/2014") }
          before(:each) do
            time_off_balance
            top_end_balance
            Employee::Balance.all.order(:effective_at).map do |balance|
              UpdateEmployeeBalance.new(balance).call
            end
          end

          it { expect(top_start_balance.reload.related_amount).to eq(-1920) }
          it { expect(time_off_balance.reload.related_amount).to eq(2880) }
          it { expect(top_end_balance.reload.related_amount).to eq(-960) }
          it { expect(top_end_balance.reload.resource_amount).to eq (-1920) }

          it { expect(top_start_balance.reload.amount).to eq(2880) }
          it { expect(time_off_balance.reload.amount).to eq(time_off_amount + 2880) }

          it { expect(etop_balance.reload.balance).to eq(4800) }
          it { expect(top_start_balance.reload.balance).to eq(7680) }
          it { expect(time_off_balance.reload.balance).to eq(4320) }
          it { expect(top_end_balance.reload.balance).to eq (4800) }
        end

        context "time off overlaps TOP start date and ETOP assignation" do
          before do
            time_off_balance
            top_end_balance
            Employee::Balance.all.order(:effective_at).map do |balance|
              UpdateEmployeeBalance.new(balance).call
            end
          end

          it { expect(etop_balance.reload.related_amount).to eq(-960) }
          it { expect(top_start_balance.reload.related_amount).to eq(-960) }
          it { expect(time_off_balance.reload.related_amount).to eq(2880) }
          it { expect(top_end_balance.reload.resource_amount).to eq (-1920) }

          it { expect(etop_balance.reload.amount).to eq(3840) }
          it { expect(top_start_balance.reload.amount).to eq(3840) }
          it { expect(time_off_balance.reload.amount).to eq(-480) }

          it { expect(etop_balance.reload.balance).to eq(3840) }
          it { expect(top_start_balance.reload.balance).to eq(7680) }
          it { expect(time_off_balance.reload.balance).to eq(4320) }
          it { expect(top_end_balance.reload.balance).to eq(4800) }
        end

        context "ETOP assignation is on time_off start_time" do
          let(:etop_effective_at) { time_off_start + 1.day}
          let(:top_start_day) { 15 }
          let(:top_end_day) { 20 }
          let(:top_balance_effective_at) { time_off_end + 5.days }

          before(:each) do
            etop_balance.calculate_and_set_balance
            top_start_balance.calculate_and_set_balance
            time_off_balance.calculate_and_set_balance
            top_start_balance.save! && time_off_balance.save! && etop_balance.save!
          end

          it { expect(etop_balance.related_amount).to eq(-480) }
          it { expect(time_off_balance.related_amount).to eq(480) }
          it { expect(top_start_balance.related_amount).to eq(0) }

          it { expect(etop_balance.amount).to eq(4320) }
          it { expect(time_off_balance.amount).to eq(-2880) }
          it { expect(top_start_balance.amount).to eq(4800) }

          it { expect(etop_balance.balance).to eq(4320) }
          it { expect(time_off_balance.balance).to eq(1920) }
          it { expect(top_start_balance.balance).to eq(6720) }
        end

        context "time_off starts middle of day" do
          let(:etop_effective_at) { Time.zone.parse("07/01/2014") }
          before do
            time_off.update!(start_time: time_off_start + 13.hours)
            time_off_balance
            top_end_balance
            Employee::Balance.all.order(:effective_at).map do |balance|
              UpdateEmployeeBalance.new(balance).call
            end
          end

          it { expect(top_start_balance.reload.related_amount).to eq(-1680) }
          it { expect(time_off_balance.reload.related_amount).to eq(2640) }
          it { expect(top_end_balance.reload.resource_amount).to eq(-2160) }

          it { expect(top_start_balance.reload.amount).to eq(3120) }
          it { expect(time_off_balance.reload.amount).to eq(-480) }

          it { expect(top_start_balance.reload.balance).to eq(7920) }
          it { expect(time_off_balance.reload.balance).to eq(4320) }
          it { expect(top_end_balance.reload.balance).to eq(4800) }
        end
      end

      context "presence policy changes during time_off" do
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

        before do
          time_off
          top_end_balance
          Employee::Balance.order(:effective_at).map do |balance|
            UpdateEmployeeBalance.new(balance).call
          end
        end

        it { expect(etop_balance.reload.related_amount).to eq(-960) }
        it { expect(top_start_balance.reload.related_amount).to eq(-480) }
        it { expect(time_off_balance.reload.related_amount).to eq(1920) }
        it { expect(top_end_balance.reload.resource_amount).to eq(-2880) }

        it { expect(etop_balance.reload.amount).to eq(3840) }
        it { expect(top_start_balance.reload.amount).to eq(4320) }
        it { expect(time_off_balance.reload.amount).to eq(-240) }

        it { expect(etop_balance.reload.balance).to eq(3840) }
        it { expect(top_start_balance.reload.balance).to eq(8160) }
        it { expect(time_off_balance.reload.balance).to eq(4560) }
        it { expect(top_end_balance.reload.balance).to eq (4800) }
      end

      context "different category" do
        let(:diff_category) { create(:time_off_category, account: account,  name: "cat2") }

        let!(:diff_category_policy) do
          create(:time_off_policy, :with_end_date, time_off_category: diff_category, start_day: 4)
        end

        let(:diff_top_start_balance) do
          create(:employee_balance, employee: employee, time_off_category: diff_category,
            effective_at: top_balance_effective_at)
        end

        it { expect(diff_top_start_balance.related_amount).to eq(0) }
      end
    end
  end

  context "effective_at_equal_time_off_policy_dates end_date edge cases" do
    # All edge cases are provided in docs about Employee::Balance
    # https://github.com/yalty/yalty-doc/blob/business_logic/business_logic/models/employee/balance.md#validations
    let(:employee) { create(:employee) }
    let!(:category) { create(:time_off_category, account: employee.account) }

    let!(:top) do
      create(:time_off_policy, time_off_category: category, start_day: start_day,
        start_month: start_month, end_day: end_day, end_month: end_month, years_to_effect: 1)
    end

    let!(:second_top) { create(:time_off_policy, time_off_category: category) }

    let!(:etop) do
      create(:employee_time_off_policy, employee: employee, time_off_policy: top,
        time_off_category: category, effective_at: etop_effective_at)
    end

    let!(:second_etop) do
      create(:employee_time_off_policy, employee: employee, time_off_policy: second_top,
        time_off_category: category, effective_at: effective_till + 1.day)
    end

    let!(:top_start_balance) do
      create(:employee_balance_manual, employee: employee, time_off_category: category,
        effective_at: Time.zone.parse("#{start_day}/#{start_month}/#{start_year}"),
        balance_type: "addition",
        validity_date: RelatedPolicyPeriod.new(etop).validity_date_for_balance_at(
          Time.zone.parse("#{start_day}/#{start_month}/#{start_year}"
        )))
    end

    let(:end_date_balance) do
      create(:employee_balance_manual, employee: employee, time_off_category: category,
        effective_at: Time.zone.parse("#{end_day + 1}/#{end_month}/#{start_year}"),
        balance_type: "removal")
    end

    let(:last_possible_balance) do
      build(:employee_balance_manual, employee: employee, time_off_category: category,
        balance_type: "removal", balance_credit_additions: [top_start_balance])
    end

    context "offset +1" do
      let(:etop_effective_at) { Time.zone.parse("01/01/2015") }
      let(:start_year) { 2016 }
      let(:start_day) { 10 }
      let(:start_month) { 2 }
      let(:end_day) { 5 }
      let(:end_month) { 1 }
      let(:expected_effective_at) { Time.zone.parse("#{end_day + 1}/#{end_month}/2018 00:00:02") }
      let(:in_2019) { Time.zone.parse("#{end_day}/#{end_month}/2019") }
      let(:in_2017) { Time.zone.parse("#{end_day}/#{end_month}/2017") }

      before { end_date_balance }

      context "E < S < T" do
        let(:effective_till) { Time.zone.parse("15/02/2016") }

        it "removal is valid" do
          expect(last_possible_balance.valid?).to be(true)
          expect(last_possible_balance.effective_at).to eq(expected_effective_at)
        end

        context "with invalid data" do
          it do
            allow(last_possible_balance).to receive(:now_or_effective_at) { in_2019 }
            expect(last_possible_balance.valid?).to be(false)
          end

          it do
            allow(last_possible_balance).to receive(:now_or_effective_at) { in_2017 }
            expect(last_possible_balance.valid?).to be(false)
          end
        end
      end

      context "E < S = T" do
        let(:effective_till) { Time.zone.parse("10/02/2016") }

        it "creates removal with proper effective_at" do
          expect(last_possible_balance.valid?).to be(true)
          expect(last_possible_balance.effective_at).to eq(expected_effective_at)
        end

        context "with invalid data" do
          it do
            allow(last_possible_balance).to receive(:now_or_effective_at) { in_2019 }
            expect(last_possible_balance.valid?).to be(false)
          end

          it do
            allow(last_possible_balance).to receive(:now_or_effective_at) { in_2017 }
            expect(last_possible_balance.valid?).to be(false)
          end
        end
      end
    end

    context "offset -1" do
      let(:etop_effective_at) { Time.zone.parse("01/01/2014") }
      let(:effective_till) { Time.zone.parse("01/01/2016") }
      let(:start_year) { 2015 }
      let(:start_day) { 10 }
      let(:start_month) { 1 }
      let(:end_day) { 10 }
      let(:expected_effective_at) { Time.zone.parse("#{end_day + 1}/#{end_month}/2016 00:00:02") }
      let(:in_2015) { Time.zone.parse("#{end_day}/#{end_month}/2015") }
      let(:in_2017) { Time.zone.parse("#{end_day}/#{end_month}/2017") }

      context "T < S < E" do
        let(:end_month) { 2 }
        before { end_date_balance }

        it "creates removal with proper effective_at" do
          expect(last_possible_balance.valid?).to be(true)
          expect(last_possible_balance.effective_at).to eq(expected_effective_at)
        end

        context "with invalid data" do
          it do
            allow(last_possible_balance).to receive(:now_or_effective_at) { in_2017 }
            expect(last_possible_balance.valid?).to be(false)
          end

          it do
            allow(last_possible_balance).to receive(:now_or_effective_at) { in_2015 }
            expect(last_possible_balance.valid?).to be(false)
          end
        end
      end

      context "T < S = E" do
        let(:end_month) { 1 }

        it "creates removal with proper effective_at" do
          expect(last_possible_balance.valid?).to be(true)
          expect(last_possible_balance.effective_at).to eq(expected_effective_at)
        end

        context "with invalid data" do
          it do
            allow(last_possible_balance).to receive(:now_or_effective_at) { in_2017 }
            expect(last_possible_balance.valid?).to be(false)
          end

          it do
            allow(last_possible_balance).to receive(:now_or_effective_at) { in_2015 }
            expect(last_possible_balance.valid?).to be(false)
          end
        end
      end
    end

    context "offset 0" do
      let(:etop_effective_at) { Time.zone.parse("01/01/2015") }
      let(:start_year) { 2015 }
      let(:expected_effective_at) { Time.zone.parse("#{end_day + 1}/#{end_month}/2017 00:00:02") }
      let(:in_2016) { Time.zone.parse("#{end_day}/#{end_month}/2016") }
      let(:in_2018) { Time.zone.parse("#{end_day}/#{end_month}/2018") }

      context "effective_till is earliest date of the 3 in the year" do
        let(:effective_till) { Time.zone.parse("05/01/2016") }
        let(:start_day) { 10 }
        let(:start_month) { 2 }
        let(:end_month) { 1 }

        context "T < E < S" do
          let(:end_day) { 1 }

          it "creates removal with proper effective_at" do
            expect(last_possible_balance.valid?).to be(true)
            expect(last_possible_balance.effective_at).to eq(expected_effective_at)
          end

          context "with invalid data" do
            it do
              allow(last_possible_balance).to receive(:now_or_effective_at) { in_2016 }
              expect(last_possible_balance.valid?).to be(false)
            end

            it do
              allow(last_possible_balance).to receive(:now_or_effective_at) { in_2018 }
              expect(last_possible_balance.valid?).to be(false)
            end
          end
        end

        context "T = E < S" do
          let(:end_day) { 5 }

          it "creates removal with proper effective_at" do
            expect(last_possible_balance.valid?).to be(true)
            expect(last_possible_balance.effective_at).to eq(expected_effective_at)
          end

          context "with invalid data" do
            it do
              allow(last_possible_balance).to receive(:now_or_effective_at) { in_2016 }
              expect(last_possible_balance.valid?).to be(false)
            end

            it do
              allow(last_possible_balance).to receive(:now_or_effective_at) { in_2018 }
              expect(last_possible_balance.valid?).to be(false)
            end
          end
        end
      end

      context "start_date is earliest date of the 3 in the year" do
        let(:effective_till) { Time.zone.parse("15/02/2016") }
        let(:start_year) { 2016 }
        let(:start_day) { 1 }
        let(:start_month) { 1 }
        let(:end_month) { 2 }
        let(:end_day) { 20 }

        context "S < T < E" do
          it "creates removal with proper effective_at" do
            expect(last_possible_balance.valid?).to be(true)
            expect(last_possible_balance.effective_at).to eq(expected_effective_at)
          end

          context "with invalid data" do
            it do
              allow(last_possible_balance).to receive(:now_or_effective_at) { in_2016 }
              expect(last_possible_balance.valid?).to be(false)
            end

            it do
              allow(last_possible_balance).to receive(:now_or_effective_at) { in_2018 }
              expect(last_possible_balance.valid?).to be(false)
            end
          end
        end

        context "S = T < E" do
          let(:effective_till) { Time.zone.parse("01/01/2016") }

          it "creates removal with proper effective_at" do
            expect(last_possible_balance.valid?).to be(true)
            expect(last_possible_balance.effective_at).to eq(expected_effective_at)
          end

          context "with invalid data" do
            it do
              allow(last_possible_balance).to receive(:now_or_effective_at) { in_2016 }
              expect(last_possible_balance.valid?).to be(false)
            end

            it do
              allow(last_possible_balance).to receive(:now_or_effective_at) { in_2018 }
              expect(last_possible_balance.valid?).to be(false)
            end
          end
        end

        context "S < T = E" do
          let(:effective_till) { Time.zone.parse("20/02/2016") }

          it "creates removal with proper effective_at" do
            expect(last_possible_balance.valid?).to be(true)
            expect(last_possible_balance.effective_at).to eq(expected_effective_at)
          end

          context "with invalid data" do
            it do
              allow(last_possible_balance).to receive(:now_or_effective_at) { in_2016 }
              expect(last_possible_balance.valid?).to be(false)
            end

            it do
              allow(last_possible_balance).to receive(:now_or_effective_at) { in_2018 }
              expect(last_possible_balance.valid?).to be(false)
            end
          end
        end

        context "S = T = E" do
          let(:effective_till) { Time.zone.parse("01/01/2016") }
          let(:end_month) { 1 }
          let(:end_day) { 1 }

          it "creates removal with proper effective_at" do
            expect(last_possible_balance.valid?).to be(true)
            expect(last_possible_balance.effective_at).to eq(expected_effective_at)
          end

          context "with invalid data" do
            it do
              allow(last_possible_balance).to receive(:now_or_effective_at) { in_2016 }
              expect(last_possible_balance.valid?).to be(false)
            end

            it do
              allow(last_possible_balance).to receive(:now_or_effective_at) { in_2018 }
              expect(last_possible_balance.valid?).to be(false)
            end
          end
        end

        context "S < E < T" do
          let(:end_day) { 5 }

          it "creates removal with proper effective_at" do
            expect(last_possible_balance.valid?).to be(true)
            expect(last_possible_balance.effective_at).to eq(expected_effective_at)
          end

          context "with invalid data" do
            it do
              allow(last_possible_balance).to receive(:now_or_effective_at) { in_2016 }
              expect(last_possible_balance.valid?).to be(false)
            end

            it do
              allow(last_possible_balance).to receive(:now_or_effective_at) { in_2018 }
              expect(last_possible_balance.valid?).to be(false)
            end
          end
        end

        context "S = E < T" do
          let(:end_month) { 1 }
          let(:end_day) { 1 }

          it "creates removal with proper effective_at" do
            expect(last_possible_balance.valid?).to be(true)
            expect(last_possible_balance.effective_at).to eq(expected_effective_at)
          end

          context "with invalid data" do
            it do
              allow(last_possible_balance).to receive(:now_or_effective_at) { in_2016 }
              expect(last_possible_balance.valid?).to be(false)
            end

            it do
              allow(last_possible_balance).to receive(:now_or_effective_at) { in_2018 }
              expect(last_possible_balance.valid?).to be(false)
            end
          end
        end
      end

      context "E < T < S" do
        let(:effective_till) { Time.zone.parse("10/01/2016") }
        let(:start_year) { 2015 }
        let(:start_day) { 10 }
        let(:start_month) { 2 }
        let(:end_month) { 1 }
        let(:end_day) { 1 }

        it "creates removal with proper effective_at" do
          expect(last_possible_balance.valid?).to be(true)
          expect(last_possible_balance.effective_at).to eq(expected_effective_at)
        end

        context "with invalid data" do
          it do
            allow(last_possible_balance).to receive(:now_or_effective_at) { in_2016 }
            expect(last_possible_balance.valid?).to be(false)
          end

          it do
            allow(last_possible_balance).to receive(:now_or_effective_at) { in_2018 }
            expect(last_possible_balance.valid?).to be(false)
          end
        end
      end
    end
  end
end
