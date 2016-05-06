require 'rails_helper'

RSpec.describe EmployeePresencePolicy, type: :model do
  let(:epp) { create(:employee_presence_policy) }

  it { is_expected.to have_db_column(:employee_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:presence_policy_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:effective_at).of_type(:date) }
  it { is_expected.to have_db_column(:start_day_order).of_type(:integer) }
  it { is_expected.to validate_presence_of(:employee_id) }
  it { is_expected.to validate_presence_of(:presence_policy_id) }
  it { is_expected.to validate_presence_of(:effective_at) }
  it { is_expected.to have_db_index([:presence_policy_id, :employee_id]) }
  it { is_expected.to have_db_index([:employee_id, :presence_policy_id, :effective_at]).unique }

  describe 'custom validations' do
    context '#no_balances_after_effective_at' do
      let(:employee) { create(:employee, created_at: Time.now - 12.years) }
      let!(:balance) { create(:employee_balance, time_off_category: category, employee: employee, time_off: time_off) }
      let!(:policy) { create(:time_off_policy, time_off_category: category) }
      let(:category) { create(:time_off_category, account_id: employee.account_id) }
      let(:presence_policy) { create(:presence_policy, account_id: employee.account_id) }
      let(:time_off) { create(:time_off, :without_balance, employee: employee, time_off_category: category) }
      let(:new_policy) do
        build(:employee_presence_policy,
          employee: balance.employee, presence_policy: presence_policy, effective_at: Time.now - 4.years
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
end
