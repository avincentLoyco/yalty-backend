require 'rails_helper'

RSpec.describe CreateBalanceJob do
  let(:account) { create(:account) }
  let(:category) { create(:time_off_category, account: account) }
  let(:policy) { create(:time_off_policy, time_off_category: category) }
  let(:employee) { create(:employee, account: account) }
  before { allow_any_instance_of(Employee).to receive(:active_policy_in_category) { policy } }

  subject { CreateBalanceJob.perform_now(category.id, employee.id, account.id, 100) }

  describe '#perform' do
    it 'should call CreateEmployeeBalance service' do
      expect_any_instance_of(CreateEmployeeBalance).to receive(:call)
      subject
    end

    context 'with valid params' do
      it { expect(subject).to eq true }
    end

    context 'with invalid params' do
      context 'invalid id' do
        before { allow_any_instance_of(Employee).to receive(:id) { 'ab' } }

        it { expect { subject }.to raise_error { ActiveRecord::RecordNotFound } }
      end

      context 'employee does not have policy' do
        before { allow_any_instance_of(Employee).to receive(:active_policy_in_category) { nil } }

        it { expect { subject }.to raise_error { API::V1::Exceptions::InvalidResourcesError } }
      end
    end
  end
end
