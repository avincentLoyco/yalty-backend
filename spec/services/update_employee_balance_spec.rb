require 'rails_helper'

RSpec.describe UpdateEmployeeBalance, type: :service do
  let!(:previous_balance) { create(:employee_balance, :processing, effective_at: Time.now - 1.week) }
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
      let!(:addition) { create(:employee_balance, validity_date: Time.now + 1.week) }
      let!(:employee_balance) do
        create(:employee_balance, :processing, balance_credit_addition: addition)
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
