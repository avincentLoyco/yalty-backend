require 'rails_helper'

RSpec.describe AssignResetEmployeeBalance do
  include_context 'shared_context_timecop_helper'
  include_context 'shared_context_account_helper'

  subject { described_class.new(etop).call }

  let(:employee) { create(:employee) }
  let(:category) { create(:time_off_category, account: employee.account) }
  let(:policy) { create(:time_off_policy, :with_end_date, time_off_category: category) }
  let!(:not_reset_etop) do
    create(:employee_time_off_policy,
      employee: employee, effective_at: 1.year.ago, time_off_policy: policy)
  end

  context 'when employee time off policy has reset resource assigned' do
    let!(:contract_end) do
      create(:employee_event,
        employee: employee, event_type: 'contract_end', effective_at: 1.month.since)
    end
    let(:etop) { employee.reload.employee_time_off_policies.with_reset.first }
    before { Employee::Balance.reset.destroy_all }

    context 'when there are no employee balances with validity dates' do

      it { expect { subject }.to change { Employee::Balance.count }.by(1) }
      it { expect { subject }.to change { Employee::Balance.reset.count }.by(1) }
    end

    context 'when there are employee balances with validity date after contract end' do
      let(:removal_date) { contract_end.effective_at + 1.day + Employee::Balance::REMOVAL_OFFSET}
      let(:date_for_not_reset) do
        not_reset_etop.effective_at + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET
      end

      let!(:not_reset_assignation) do
        create(:employee_balance_manual,
          employee: employee, time_off_category: category, policy_credit_addition: true,
          effective_at: date_for_not_reset, manual_amount: 1000,
          validity_date: Time.new(2015, 4, 1) + Employee::Balance::REMOVAL_OFFSET)
      end

      let!(:first_start_date) do
        create(:employee_balance_manual,
          employee: employee, time_off_category: category, policy_credit_addition: true,
          effective_at: date_for_not_reset + 1.year, resource_amount: policy.amount,
          validity_date: Time.new(2016, 4, 1) + Employee::Balance::REMOVAL_OFFSET)
      end

      it { expect { subject }.to_not change { not_reset_assignation.reload.validity_date } }
      it { expect { subject }.to change { first_start_date.reload.balance_credit_removal_id } }
      it do
        expect { subject }
          .to change { first_start_date.reload.validity_date }.to eq removal_date
      end
    end
  end

  context 'when employee time off policy does not have reset resource assigned' do
    let(:etop) { not_reset_etop }

    it { expect { subject }.to_not change { Employee::Balance.count } }
  end
end
