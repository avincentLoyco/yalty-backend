require 'rails_helper'

RSpec.describe PresencePolicy, type: :model do
  let!(:employee) { create(:employee, :with_presence_policy) }

  it { is_expected.to have_db_column(:name).of_type(:string) }
  it { is_expected.to have_db_column(:account_id).of_type(:uuid) }
  it { is_expected.to have_many(:employees) }
  it { is_expected.to have_many(:presence_days) }
  it { is_expected.to have_many(:time_entries) }
  it { is_expected.to have_many(:employee_presence_policies) }
  it { is_expected.to belong_to(:account) }
  it { is_expected.to validate_presence_of(:account_id) }
  it { is_expected.to validate_presence_of(:name) }

  context 'scopes' do
    context '.active_for_employee' do
      let(:presence_policy) { create(:presence_policy) }

      subject { described_class.active_for_employee(employee.id, Time.now) }

      it { expect(subject.valid?).to eq true }

      it { expect(subject.account_id).to eq employee.account_id }
      it { expect(subject.id).not_to eq presence_policy.id }
    end

    context '.for_account' do
      let(:account) { create(:account) }
      let!(:presence_policies) { create_list(:presence_policy, 3, account: account) }
      let!(:other_presence_policies) { create_list(:presence_policy, 3) }

      subject(:for_account_scope) { described_class.for_account(account.id) }

      it 'returns presence policies only for given account' do
        expect(for_account_scope.count).to eq(3)
        expect(for_account_scope).to match_array(presence_policies)
      end
    end
  end

  context 'helper methods' do
    context '#last_day_order' do
      let(:bigger_order) { 5 }
      let(:smaller_order) { 2 }

      before do
        create(:presence_day, order: bigger_order, presence_policy: employee.presence_policies.first)
        create(:presence_day, order: smaller_order, presence_policy: employee.presence_policies.first)
      end

      subject { employee.presence_policies.first.last_day_order }

      it { expect(subject).to eq bigger_order }
      it { expect(subject).not_to eq smaller_order }
    end
  end
end
