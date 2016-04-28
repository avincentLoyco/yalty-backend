require 'rails_helper'

RSpec.describe API::V1::EmployeeTimeOffPoliciesController, type: :controller do
  include_context 'shared_context_headers'
  include_context 'shared_context_timecop_helper'

  describe 'POST #create' do
    subject { post :create, params }

    let(:category) { create(:time_off_category, account: Account.current) }
    let(:employee) { create(:employee, account: Account.current) }
    let(:time_off_policy) { create(:time_off_policy, time_off_category: category) }
    let(:params) do
      {
        id: employee.id,
        time_off_policy_id: time_off_policy.id,
        effective_at: Time.now
      }
    end

    context 'with valid params' do
      it { expect { subject }.to change { employee.employee_time_off_policies.count }.by(1) }

      it { is_expected.to have_http_status(201) }

      context 'response body' do
        before { subject }

        it { expect_json_keys(:id, :type, :assignation_type, :effective_at, :assignation_id) }
      end
    end

    context 'with invalid params' do
      let(:new_account) { create(:account) }

      context 'when employee does not belong to current account' do
        before { employee.update!(account: new_account) }

        it { expect { subject }.to_not change { employee.employee_time_off_policies.count } }
        it { is_expected.to have_http_status(404) }
      end

      context 'when time off policy does not belong to current account' do
        before { category.update!(account: new_account) }

        it { expect { subject }.to_not change { employee.employee_time_off_policies.count } }
        it { is_expected.to have_http_status(404) }
      end
    end
  end
end
