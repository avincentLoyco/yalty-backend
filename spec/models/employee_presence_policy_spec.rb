require 'rails_helper'

RSpec.describe EmployeePresencePolicy, type: :model do
  let(:epp) { create(:employee_presence_policy) }

  it { is_expected.to have_db_column(:employee_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:presence_policy_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:effective_at).of_type(:date) }
  it { is_expected.to have_db_column(:order_of_start_day).of_type(:integer) }
  it { is_expected.to validate_presence_of(:employee_id) }
  it { is_expected.to validate_presence_of(:presence_policy_id) }
  it { is_expected.to validate_presence_of(:effective_at) }
  it { is_expected.to have_db_index([:presence_policy_id, :employee_id]) }
  it { is_expected.to have_db_index([:employee_id, :presence_policy_id, :effective_at]).unique }

  describe 'validations' do
    context '#no_balances_after_effective_at' do
      let(:employee) { create(:employee, created_at: Time.now - 12.years) }
      let!(:policy) { create(:time_off_policy, time_off_category: category) }
      let(:category) { create(:time_off_category, account_id: employee.account_id) }
      let(:balance) { time_off.employee_balance }
      let(:time_off) do
        create(:time_off, employee: employee, time_off_category: category)
      end
      let(:new_policy) do
        build(:employee_presence_policy,
          employee: balance.employee,
          effective_at: Time.now - 4.years
        )
      end

      subject { new_policy }

      context 'when there is no employee balance from a time off after the effective_at' do
        let(:effective_at) { Time.now - 6.years }
        before { balance.update_attribute(:effective_at, effective_at) }

        it { expect(subject.valid?).to eq true }
        it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }
      end

      context 'when there is employee balance from a time off after the effective_at' do
        let(:effective_at) { Time.now - 2.years }

        before { balance.update_attribute(:effective_at, effective_at) }

        it { expect(subject.valid?).to eq false }
        it { expect { subject.valid? }.to change { subject.errors.messages[:effective_at] }
          .to include('Employee balance after effective at already exists') }
      end
    end
  end

  context 'order_of_start_day numericality' do
    let(:presence_policy) { create(:presence_policy, presence_days: [end_day]) }
    let(:end_day) { build(:presence_day, order: 4) }
    subject do
      build(:employee_presence_policy, presence_policy: presence_policy, order_of_start_day: order)
    end

    context 'with valid params' do
      let(:order) { 1 }

      it { expect(subject.valid?).to eq true }
      it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }
    end

    context 'when order_of_start_day is too small' do
      let(:order) { 0 }

      it { expect(subject.valid?).to eq false }
      it { expect { subject.valid? }.to change { subject.errors.messages[:order_of_start_day] }
        .to include('must be greater than 0') }
    end

    context 'when order_of_start_day is bigger than last assigned day' do
      let(:order) { 6 }

      it { expect(subject.valid?).to eq false }
      it { expect { subject.valid? }.to change { subject.errors.messages[:order_of_start_day] }
        .to include('Must be smaller than last presence day order') }
    end
  end

  context 'callbacks' do
    context '.trigger_intercom_update' do
      let(:account) { create(:account) }
      let(:employee) { create(:employee, account: account) }

      subject(:create_policy) do
        create(:employee_presence_policy, employee: employee)
      end

      it 'should trigger intercom update on account' do
        expect(account).to receive(:create_or_update_on_intercom).with(true).at_least(:once)
        create_policy
      end

      context 'with user' do
        let(:user) { create(:account_user, account: account) }
        let(:employee) { create(:employee, account: account, user: user) }

        it 'should trigger intercom update on user' do
          expect(user).to receive(:create_or_update_on_intercom).with(true).at_least(:once)
          create_policy
        end
      end

      context 'without user' do
        it 'should not trigger intercom update on user' do
          expect_any_instance_of(Account::User)
            .not_to receive(:create_or_update_on_intercom).with(true)
          create_policy
        end
      end
    end
  end
end
