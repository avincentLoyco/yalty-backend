require 'rails_helper'

RSpec.describe UpdateEmployeeBalance, type: :service do
  let!(:previous_balance) { create(:employee_balance, :processing, created_at: Time.now - 1.week) }
  let(:employee_balance) { previous_balance.dup }
  subject { UpdateEmployeeBalance.new(employee_balance, amount).call }
  before do
    employee_balance.save
    previous_balance.save
  end

  context 'when amount not given' do
    let(:amount) { nil }

    it { expect { subject }.to change { employee_balance.reload.beeing_processed }.to false}
    it { expect { subject }.to_not change { Employee::Balance.count } }
    it { expect { subject }.to_not change { employee_balance.reload.amount } }
    it { expect { subject }.to change { employee_balance.reload.balance } }
  end

  context 'when amount given' do
    let(:amount) { 100 }

    it { expect { subject }.to change { employee_balance.reload.beeing_processed }.to false}
    it { expect { subject }.to_not change { Employee::Balance.count } }
    it { expect { subject }.to change { employee_balance.reload.balance } }
    it { expect { subject }.to change { employee_balance.reload.amount } }
  end

  context 'when amount in invalid format' do
    let(:amount) { 'test' }

    it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
  end
end
