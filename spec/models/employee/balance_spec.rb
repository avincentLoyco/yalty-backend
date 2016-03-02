require 'rails_helper'

RSpec.describe Employee::Balance, type: :model do
  it { is_expected.to have_db_column(:id).of_type(:uuid) }
  it { is_expected.to have_db_column(:balance).of_type(:integer).with_options(default: 0) }
  it { is_expected.to have_db_column(:amount).of_type(:integer).with_options(default: 0) }
  it { is_expected.to have_db_column(:employee_id).of_type(:uuid).with_options(null: false) }
  it { is_expected.to have_db_column(:time_off_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:time_off_policy_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:time_off_category_id)
    .of_type(:uuid).with_options(null: false) }
  it { is_expected.to have_db_column(:validity_date).of_type(:datetime) }
  it { is_expected.to have_db_column(:policy_credit_removal).of_type(:boolean)
    .with_options(default: false) }
  it { is_expected.to have_db_column(:balance_credit_addition_id).of_type(:uuid) }

  it { is_expected.to have_db_index(:time_off_id) }
  it { is_expected.to have_db_index(:time_off_category_id) }
  it { is_expected.to have_db_index(:employee_id) }
  it { is_expected.to have_db_index(:time_off_policy_id) }

  it { is_expected.to validate_presence_of(:employee) }
  it { is_expected.to validate_presence_of(:time_off_category) }
  it { is_expected.to validate_presence_of(:balance) }

  context 'callbacks' do
    subject { build(:employee_balance, amount: 200) }

    context 'balance calculation' do
      context 'when balance first in policy' do
        it { expect { subject.valid? }.to change { subject.balance }.to(200) }
      end

      context 'when balances before already exist' do
        before do
          create(:employee_balance,
            amount: 100, employee: employee, time_off_policy: subject.time_off_policy
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
        it { expect { subject.valid? }.to change { subject.effective_at }.to be_kind_of(Time) }
      end

       context 'when balance is removal' do
        let(:addition) { create(:employee_balance, validity_date: Time.now + 1.week ) }
        subject { build(:employee_balance, amount: 200, balance_credit_addition: addition) }

        it { expect { subject.valid? }.to change { subject.effective_at } }

        context 'removal effective at equals addition validity date' do
          before { subject.valid? }

          it { expect(subject.effective_at.to_date).to eq addition.validity_date.to_date }
        end
      end

      context 'when effective at already set' do
        subject { build(:employee_balance, amount: 200, effective_at: Time.now - 1.week) }

        it { expect { subject.valid? }.to_not change { subject.effective_at } }
      end

      context 'when employee balance has time off' do
        let(:time_off) { create(:time_off, start_time: Date.today - 1.month) }
        subject { build(:employee_balance, time_off: time_off) }

        it { expect { subject.valid? }.to change { subject.effective_at } }

        context 'effective_at date value' do
          before { subject.valid? }

          it { expect(subject.effective_at).to eq time_off.start_time }
        end
      end
    end
  end

  context 'validations' do
    context 'time_off_policy date' do
      let(:time_off_policy) { create(:time_off_policy, :with_end_date) }
      subject do
        build(:employee_balance,
          time_off_policy: time_off_policy, effective_at: Time.new(2016, 5, 10)
        )
      end

      it { expect(subject.valid?).to eq false }
      it { expect { subject.valid? }.to change { subject.errors.size } }
      it { expect { subject.valid? }.to change { subject.errors.messages[:effective_at] }
        .to include('Must belong to current, next or previous policy.') }
    end

    context 'counter validity date blank' do
      let(:policy) { create(:time_off_policy, policy_type: 'counter') }
      let(:employee_balance) do
        build(:employee_balance, time_off_policy: policy, effective_at: Date.today - 1.day)
      end
      subject { employee_balance.valid? }

      context 'when validity date is nil' do
        it { expect(subject).to eq true }
        it { expect { subject }.to_not change { employee_balance.errors.size } }
      end

      context 'when validity date is present' do
        before { employee_balance.validity_date = Date.today }

        context 'and policy is a counter type' do
          it { expect(subject).to eq false }
          it { expect { subject }.to change { employee_balance.errors.size } }
        end

        context 'and policy is a balancer type' do
          before { policy.update!(policy_type: 'balancer') }

          it { expect(subject).to eq true }
          it { expect { subject }.to_not change { employee_balance.errors.size } }
        end
      end
    end

    context 'removal effective at date' do
      before { allow_any_instance_of(Employee::Balance).to receive(:find_effective_at) { true } }
      subject { removal.valid? }

      let(:balance_addition) do
        create(:employee_balance, validity_date: Date.today, effective_at: Date.today - 1.week)
      end
      let(:removal) do
        build(:employee_balance, balance_credit_addition: balance_addition, effective_at: Date.today)
      end

      context 'when removal effective_at valid' do
        it { expect { subject }.to_not change { removal.errors.size } }
        it { expect(subject).to eq true }
      end

      context 'when removal effective at not valid' do
        before { removal.effective_at = Date.today - 1.month }

        it { expect(subject).to eq false }
        it { expect { subject }.to change { removal.errors.size } }
        it { expect { subject }.to change { removal.errors.messages[:effective_at] }
          .to include('Removal effective at must equal addition validity date') }
      end
    end

    context 'amount numericallty' do
      subject { balance.valid? }
      let(:balance) do
        build(:employee_balance,
          effective_at: Date.today - 1.day, validity_date: Date.today, amount: 100
        )
      end

      context 'when valid amount' do
        it { expect { subject }.to_not change { balance.errors.size } }
        it { expect(subject).to eq true }
      end

      context 'when invalid amount' do
        before { balance.amount =  -100 }

        it { expect(subject).to eq false }
        it { expect { subject }.to change { balance.errors.size } }
        it { expect { subject }.to change { balance.errors.messages[:amount] }
          .to include('must be greater than or equal to 0') }
      end
    end
  end
end
