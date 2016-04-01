require 'rails_helper'

RSpec.describe UpdateEmployeeBalance, type: :service do
  before do
    allow_any_instance_of(Employee).to receive(:active_policy_in_category_at_date)
      .and_return(employee_policy)
    allow_any_instance_of(Employee).to receive(:active_related_time_off_policy)
      .and_return(employee_policy)
  end
  let(:account) { create(:account) }
  let(:category) { create(:time_off_category, account: account) }
  let(:employee) { create(:employee, account: account) }
  let(:policy) { create(:time_off_policy, time_off_category: category) }
  let(:employee_policy) do
    create(:employee_time_off_policy, employee: employee)
  end
  let!(:previous_balance) do
    create(:employee_balance, :processing,
      effective_at: Time.now - 1.week, time_off_category: category, employee: employee
    )
  end
  let(:employee_balance) { previous_balance.dup }
  subject { UpdateEmployeeBalance.new(employee_balance, options).call }
  before do
    employee_balance.effective_at = Time.now
    employee_balance.save
    previous_balance.save
  end

  context 'when amount not given' do
    let(:options) {{ amount: nil }}

    context 'and employee balance is removal' do
      let!(:addition) do
        create(:employee_balance,
          validity_date: Time.now + 1.week, time_off_category: category,
          employee: previous_balance.employee
        )
      end
      let!(:employee_balance) do
        create(:employee_balance, :processing,
          balance_credit_addition: addition, time_off_category: category,
          employee: previous_balance.employee
        )
      end
      subject { UpdateEmployeeBalance.new(employee_balance, options).call }

      it { expect { subject }.to change { employee_balance.reload.being_processed }.to false }
      it { expect { subject }.to_not change { Employee::Balance.count } }
      it { expect { subject }.to change { employee_balance.reload.balance } }
      it { expect { subject }.to change { employee_balance.reload.amount } }
    end

    context 'and employee balance is not removal' do
      it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
    end
  end

  context 'when amount given' do
    let(:options) {{ amount: 100 }}

    it { expect { subject }.to change { employee_balance.reload.being_processed }.to false }
    it { expect { subject }.to_not change { Employee::Balance.count } }
    it { expect { subject }.to change { employee_balance.reload.balance } }
    it { expect { subject }.to change { employee_balance.reload.amount } }
  end
end
