require 'rails_helper'

RSpec.describe API::V1::EmployeeTimeOffPoliciesController, type: :controller do
  include_context 'shared_context_headers'
  include_context 'shared_context_timecop_helper'

  let(:category) { create(:time_off_category, account: Account.current) }
  let(:employee) { create(:employee, account: Account.current) }
  let(:time_off_policy) { create(:time_off_policy, time_off_category: category) }
  let(:time_off_policy_id) { time_off_policy.id }

  describe 'GET #index' do
    subject { get :index, time_off_policy_id: time_off_policy_id }

    let!(:first_employee_policy) do
      create(:employee_time_off_policy,
        employee: employee, effective_at: Time.now + 1.year, time_off_policy: time_off_policy
      )
    end
    let!(:second_employee_policy) do
      create(:employee_time_off_policy,
        employee: employee, effective_at: Time.now + 5.month, time_off_policy: time_off_policy
      )
    end

    context 'with valid time_off_policy' do
      let(:time_off_policy_id) { time_off_policy.id }

      it { is_expected.to have_http_status(200) }

      context 'response' do
        before { subject }

        it { expect_json_sizes(2) }
        it { expect(response.body).to include(employee.id) }
        it { expect(response.body).to include(first_employee_policy.id, second_employee_policy.id) }
        it { expect_json_keys(
          '*', [:id, :type, :assignation_id, :assignation_type, :effective_at, :effective_till])
        }
      end
    end

    context 'with invalid time_off_policy' do
      let(:time_off_policy_id) { 'a' }

      it { is_expected.to have_http_status(404) }
    end

    context 'when policy does not belong to current account' do
      before { Account.current = create(:account) }

      it { is_expected.to have_http_status(404) }
    end
  end

  describe 'POST #create' do
    subject { post :create, params }

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

        it { expect_json_keys(:id, :type, :assignation_type, :aaa, :effective_at, :assignation_id) }
      end
    end

    context 'with invalid params' do
      let(:new_account) { create(:account) }

      context 'when there is employee balance after effective at' do
        let!(:balance) do
          create(:employee_balance,
            employee: employee, effective_at: Time.now + 1.year, time_off_category: category
          )
        end

        it { expect { subject }.to_not change { employee.employee_time_off_policies.count } }
        it { is_expected.to have_http_status(422) }
      end

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
