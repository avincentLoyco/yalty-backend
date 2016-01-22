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

  context 'with valid params' do
    context 'when employee balance do not exist' do
      let(:params) {{ amount: 100 }}
      subject { CreateEmployeeBalance.new(category, employee, nil, params).call }

      it { expect { subject }.to change { Employee::Balance.count }.by(1) }
      it { expect { subject }.to change { employee.reload.employee_balances.count }.by(1) }
      it { expect { subject }.to change { policy.reload.employee_balances.count }.by(1) }
      it { expect { subject }.to change { category.reload.employee_balances.count }.by(1) }

      it { expect(subject[:balance]).to eq 100 }
    end

    context 'when employee balance already exist' do
      subject { CreateEmployeeBalance.new(category, employee, nil, params).call }
      let(:params) {{ amount: 100, id: balance.id }}
      let!(:balance) do
        create(:employee_balance,
          employee: employee, time_off_policy: policy, time_off_category: category, amount: 200
        )
      end

      it { expect { subject }.to_not change { Employee::Balance.count } }
      it { expect { subject }.to_not change { employee.reload.employee_balances.count } }
      it { expect { subject }.to_not change { policy.reload.employee_balances.count } }
      it { expect { subject }.to_not change { category.reload.employee_balances.count } }
      it { expect { subject }.to change { balance.reload.balance } }
      it { expect { subject }.to change { balance.reload.amount } }

      it { expect(subject[:balance]).to eq(100) }
    end
  end

  context 'with invalid params' do
    subject { CreateEmployeeBalance.new(category, employee, nil, params).call }
    let(:params) {{ amount: 100 }}

    context 'when params are missing' do
      context 'employee is missing' do
        subject { CreateEmployeeBalance.new(category, nil, nil, params).call }

        it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
      end

      context 'category is missing' do
        subject { CreateEmployeeBalance.new(nil, employee, nil, params).call }

        it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
      end
    end

    context 'when amount in invalid type' do
      let(:params) {{ amount: 'test' }}

      it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
    end

    context 'when time off policy in category does not exis' do
      before { working_place_policy.destroy! }

      it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
    end
  end
end
