require 'rails_helper'

RSpec.describe PrepareEmployeeBalancesToUpdate, type: :service do
  before { allow_any_instance_of(FindEmployeeBalancesToUpdate).to receive(:call) { balances } }
  subject { PrepareEmployeeBalancesToUpdate.new(resource).call }

  let(:resource) { create(:employee_balance) }
  let(:time_off) { create(:time_off, employee_balance: balance) }
  let(:employee_balance) { create(:employee_balance) }

  context 'when resource has time off' do
    let(:balance) { resource }
    let(:balances) { [resource.id, employee_balance.id] }

    it { expect { subject }.to change { resource.reload.being_processed }.to true }
    it { expect { subject }.to change { employee_balance.reload.being_processed }.to true }
    it { expect { subject }.to change { time_off.reload.being_processed }.to true }
  end

  context 'when resource does not have time off' do
    let(:balance) { employee_balance }
    let(:balances) { [resource.id, employee_balance.id] }

    it { expect { subject }.to change { resource.reload.being_processed }.to true }
    it { expect { subject }.to change { employee_balance.reload.being_processed }.to true }
    it { expect { subject }.to_not change { time_off.reload.being_processed } }
  end

  context 'when resource only in category' do
    let(:balances) { [resource.id] }

    it { expect { subject }.to change { resource.reload.being_processed }.to true }
    it { expect { subject }.to_not change { employee_balance.reload.being_processed } }
  end
end
