require 'rails_helper'

RSpec.describe Employee::Balance, type: :model do
  include_context 'shared_context_timecop_helper'
  it { is_expected.to have_db_column(:id).of_type(:uuid) }
  it { is_expected.to have_db_column(:balance).of_type(:integer).with_options(default: 0) }
  it { is_expected.to have_db_column(:employee_id).of_type(:uuid).with_options(null: false) }
  it { is_expected.to have_db_column(:time_off_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:employee_time_off_policy_id).of_type(:uuid) }
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
    let(:balance) { build(:employee_balance, resource_amount: 200, time_off_category: time_off_category) }
    let(:policy) { create(:time_off_policy, time_off_category: time_off_category) }
    let(:employee_policy) do
      build(:employee_time_off_policy,
        employee: balance.employee, time_off_policy: policy, effective_at: Date.today - 6.years
      )
    end

    before do
      allow_any_instance_of(Employee).to receive(:active_policy_in_category_at_date)
        .and_return(employee_policy)
      allow_any_instance_of(Employee).to receive(:active_policy_in_category_at_date)
        .and_return(employee_policy)
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
            create(:employee_time_off_policy, time_off_policy: policy, employee: employee)
            create(:employee_balance,
              resource_amount: 100, employee: employee, time_off_category: time_off_category,
              effective_at: Date.today - 1.week
            )
          end

          context 'and belongs to other employee' do
            let(:employee) { create(:employee) }
            it { expect { subject.valid? }.to change { subject.balance }.to(200) }
          end

          context 'and belong to current balance employee' do
            let(:employee) { subject.employee }

            it { expect { subject.valid? }.to change { subject.balance }.to(300) }
          end
        end
      end

      context 'effective at set up' do
        context 'when effective at nil' do
          xit { expect { subject.valid? }.to change { subject.effective_at }.to be_kind_of(Time) }
        end

         context 'when balance is removal' do
          before { balance.balance_credit_additions << addition }
          let(:addition) do
            create(:employee_balance,
              employee: subject.employee,
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
          let(:time_off) { create(:time_off, start_time: Date.today - 1.week) }
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
      let(:policy) { build(:time_off_policy) }
      before do
        allow_any_instance_of(Employee::Balance).to receive(:time_off_policy) { policy }
      end

      context 'effective_after_employee_creation' do
        subject { build(:employee_balance, effective_at: effective_at) }

        context 'when effective at before employee creation' do
          let(:effective_at) { Time.now - 11.years }
          let(:employee) { create(:employee) }
          let(:balance) { described_class.new(resource_amount: 200, employee: employee, effective_at: Time.now - 10.years) }
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
          before { allow_any_instance_of(Employee::Balance).to receive(:time_off_policy) { nil } }

          it { expect(subject.valid?).to eq false }
          it { expect { subject.valid? }.to change { subject.errors.messages[:employee] }
            .to include('Must have time off policy in category') }
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
          build(:employee_balance, :with_time_off)
        end

        it { expect(subject.valid?).to eq true }
        it { expect { subject.valid? }.to_not change { subject.errors.size } }

      end
      context 'effective_at_equal_time_off_policy_dates' do
        subject do
          build(:employee_balance, employee_time_off_policy: employee_policy, effective_at: effective_at)
        end

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

          context 'when it has an employee time off policy' do
            let(:policy) { create(:time_off_policy) }

            let(:employee_policy) do
              create(:employee_time_off_policy,
                employee: balance.employee, time_off_policy: policy, effective_at: Date.today - 6.years
              )
            end

            subject do
              build(:employee_balance, employee_time_off_policy: employee_policy, effective_at: effective_at)
            end

            let(:effective_at) { Time.now - 1.month }

            it { expect(subject.valid?).to eq false }
            it { expect { subject.valid? }.to change { subject.errors.messages[:effective_at] }
              .to include 'Must be at TimeOffPolicy  assignations date, end date, start date'\
              ' or the previous day to start date' }
          end

          context 'when it has no employee time off policy nor time off' do
            let(:effective_at) { employee_policy.effective_at  + 7.days}

            it { expect(subject.valid?).to eq false }
            it { expect { subject.valid? }.to change { subject.errors.messages[:time_off_id] }
              .to include 'Balance should have a employee_time_off_policy or time off' }
            it { expect { subject.valid? }.to change { subject.errors.messages[:employee_time_off_policy_id] }
              .to include 'Balance should have a employee_time_off_policy or time off' }
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
            employee: subject.employee
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
  end
end
