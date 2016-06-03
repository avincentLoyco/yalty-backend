require 'rails_helper'

RSpec.describe EmployeeTimeOffPolicy, type: :model do
  let(:etop) { create(:employee_time_off_policy) }

  it { is_expected.to have_db_column(:employee_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:time_off_policy_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:time_off_category_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:effective_at).of_type(:date) }
  it { is_expected.to validate_presence_of(:employee_id) }
  it { is_expected.to validate_presence_of(:time_off_policy_id) }
    it { is_expected.to validate_presence_of(:effective_at) }
  it { is_expected.to have_db_index([:time_off_policy_id, :employee_id]) }
  it '' do
    is_expected.to have_db_index([:employee_id, :time_off_policy_id, :effective_at]).unique
  end

  it 'the category_id must be the one to whihc the policy belongs' do
    expect(etop.time_off_category_id).to eq(etop.time_off_policy.time_off_category_id)
  end

  describe '#verify_not_change_of_policy_type_in_category' do
    let(:category) { create(:time_off_category, account: account) }
    let(:account) { create(:account) }
    let(:employee) {create(:employee, account: account) }
    context 'when there are existing etops' do
      let(:topBalancer) { create(:time_off_policy, time_off_category: category) }
      let!(:etopBalancer) do
        create(:employee_time_off_policy, employee: employee, time_off_policy: topBalancer)
      end

      context 'in the same category' do
        let(:topCounter) { create(:time_off_policy, :as_counter, time_off_category: category) }
        let(:etopCounter) do
          build(:employee_time_off_policy, employee: employee, time_off_policy: topCounter)
        end

        it '' do
          etopCounter.valid?
          expected_message = 'The employee has an existing policy of different type in the category'
          expect(etopCounter.errors.messages[:policy_type]).to eq([expected_message])
        end
      end

      context 'but not in this category' do
        let(:other_category) { create(:time_off_category, account: account) }
        let(:topCounter) { create(:time_off_policy, :as_counter, time_off_category: other_category) }
        let(:etopCounter) do
          build(:employee_time_off_policy, employee: employee, time_off_policy: topCounter)
        end

        it '' do
          expect(etopCounter).to be_valid
        end
      end
    end
  end

  describe 'custom validations' do
    context '#no_balances_after_effective_at' do
      let(:employee) { create(:employee) }
      let(:effective_at) { Time.now + 1.day }
      let!(:balance) { create(:employee_balance, effective_at: effective_at, employee: employee) }
      let(:policy) { TimeOffPolicy.first }
      let(:new_policy) do
        build(:employee_time_off_policy,
          employee: balance.employee, time_off_policy: policy, effective_at: Time.now - 4.years
        )
      end

      subject { new_policy }

      context 'when there is no employee balance in a future' do
        let(:effective_at) { Time.now - 5.years }

        it { expect(subject.valid?).to eq true }
        it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }
      end

      context 'when there is employee balance in the future' do
        let(:effective_at) { Time.now - 2.years }

        it { expect(subject.valid?).to eq false }
        it { expect { subject.valid? }.to change { subject.errors.messages[:time_off_category] }
          .to include('Employee balance after effective at already exists') }
      end
    end

    context '#effective_at_newer_than_previous_start_date' do
      let(:employee_policy) { build(:employee_time_off_policy, effective_at: effective_at) }
      let(:effective_at) { Time.now }
      subject { employee_policy.valid? }

      context 'when employee does not have other policies' do
        it { expect(subject).to eq true }
        it { expect { subject }.to_not change { employee_policy.errors.messages.count } }
      end

      context 'when employee does have other policies' do
        let(:category) { employee_policy.time_off_policy.time_off_category }
        let(:old_policy) { create(:time_off_policy, time_off_category: category) }
        let!(:previous_employee_policy) do
          create(:employee_time_off_policy,
            employee: employee_policy.employee, time_off_policy: old_policy
          )
        end

        context 'and new policy dates are valid' do
          it { expect(subject).to eq true }
          it { expect { subject }.to_not change { employee_policy.errors.messages.count } }
        end

        context 'and new policy dates outside current next and previous period are valid' do
          let(:effective_at) { '31.12.2014'.to_date }

          it { expect(subject).to eq true }
          it { expect { subject }.to_not change { employee_policy.errors.messages.count } }
        end
      end
    end
  end
end
