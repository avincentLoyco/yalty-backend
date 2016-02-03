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
  it { is_expected.to have_db_column(:validity_date).of_type(:date) }
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

      context 'when effective at already set' do
        subject { build(:employee_balance, amount: 200, effective_at: Time.now - 1.week) }

        it { expect { subject.valid? }.to_not change { subject.effective_at } }
      end
    end

    context 'validity_date set up' do
      subject { build(:employee_balance, amount: 200, time_off_policy: time_off_policy) }

      context 'when time off policy has end date' do
        let(:time_off_policy) { create(:time_off_policy, :with_end_date) }

        it { expect { subject.valid? }.to change { subject.validity_date }.to be_kind_of(Date) }
      end

      context 'when time off policy does not have end date' do
        let(:time_off_policy) { build(:time_off_policy) }

        it { expect { subject.valid? }.to_not change { subject.validity_date } }
      end
    end
  end

  context 'custom validations' do
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
  end
end
