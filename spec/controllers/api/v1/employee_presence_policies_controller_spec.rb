require 'rails_helper'

RSpec.describe API::V1::EmployeePresencePoliciesController, type: :controller do
  include_context 'shared_context_headers'
  include_context 'shared_context_timecop_helper'

  let(:presence_policy) { create(:presence_policy, account: account) }
  let(:employee) { create(:employee, account: Account.current) }

  describe 'GET #index' do
    subject { get :index, presence_policy_id: presence_policy.id }

    let!(:employee_presence_policies) do
      today = Date.today
      [today, today + 1.day, today + 2.days].map do |day|
        create(:employee_presence_policy, presence_policy: presence_policy, employee: employee, effective_at: day)
      end
    end

    context 'with valid presence_policy' do
      it { is_expected.to have_http_status(200) }

      context 'response' do
        before { subject }

        it { expect_json_sizes(3) }
        it '' do
          expect_json_keys(
            '*',
            [
              :id,
              :type,
              :assignation_type,
              :effective_at,
              :assignation_id,
              :order_of_start_day,
              :effective_till
            ]
          )
        end
      end
    end

    context 'with invalid presence_policy' do
      subject { get :index, presence_policy_id: '1' }

      it { is_expected.to have_http_status(404) }
    end
  end

  describe 'POST #create' do
    subject { post :create, params }

    let(:params) do
      {
        id: employee.id,
        presence_policy_id: presence_policy.id,
        effective_at: Time.zone.today,
        order_of_start_day: 1
      }
    end

    context 'with valid params' do
      it { expect { subject }.to change { employee.employee_presence_policies.count }.by(1) }

      it { is_expected.to have_http_status(201) }

      context 'response body' do
        before { subject }

        it '' do
          expect_json_keys(
            :id,
            :type,
            :assignation_type,
            :effective_at,
            :assignation_id,
            :order_of_start_day,
            :effective_till
          )
        end
      end
    end

    context 'with invalid params' do
      let(:new_account) { create(:account) }
      let(:category) { create(:time_off_category, account_id: employee.account_id) }
      let(:presence_policy) { create(:presence_policy, account_id: employee.account_id) }
      let(:time_off) { create(:time_off, :without_balance, employee: employee, time_off_category: category) }

      context 'when there is employee balance after effective at' do
        let!(:balance) do
          create(:employee_balance,
            employee: employee, effective_at: Time.zone.today + 1.year, time_off_category: category,
            time_off: time_off
          )
        end

        it { expect { subject }.to_not change { employee.employee_presence_policies.count } }
        it { is_expected.to have_http_status(422) }
      end

      context 'when employee does not belong to current account' do
        before { employee.update!(account: new_account) }

        it { expect { subject }.to_not change { employee.employee_presence_policies.count } }
        it { is_expected.to have_http_status(404) }
      end

      context 'when the presence policy does not belong to current account' do
        before { presence_policy.update!(account: new_account) }

        it { expect { subject }.to_not change { employee.employee_presence_policies.count } }
        it { is_expected.to have_http_status(404) }
      end
    end
  end
end
