require 'rails_helper'

RSpec.describe CreateEmployeeBalance, type: :service do
  before { Account.current = create(:account) }
  let(:employee) { create(:employee, account: Account.current) }
  let(:category) { create(:time_off_category, account: Account.current) }
  let(:policy) { create(:time_off_policy, time_off_category: category) }
  let!(:working_place_policy) do
    create(:working_place_time_off_policy,
      working_place: employee.working_place, time_off_policy: policy
    )
  end
  let(:amount) { 100 }

  subject do
    CreateEmployeeBalance.new(category.id, employee.id, Account.current.id, amount, nil).call
  end

  context 'with valid params' do
    it { expect { subject }.to change { Employee::Balance.count }.by(1) }
    it { expect { subject }.to change { employee.reload.employee_balances.count }.by(1) }
    it { expect { subject }.to change { policy.reload.employee_balances.count }.by(1) }
    it { expect { subject }.to change { category.reload.employee_balances.count }.by(1) }

    it { expect(subject[:balance]).to eq 100 }
    it { expect(subject[:amount]).to eq 100 }
  end

  context 'with invalid params' do
    context 'amount in invalid format' do
      let(:amount) { 'test' }

      it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
    end

    context 'time off policy does not exist' do
      before { working_place_policy.destroy! }

      it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
    end
  end
end
