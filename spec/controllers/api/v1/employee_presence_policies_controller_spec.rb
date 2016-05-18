require 'rails_helper'

RSpec.describe API::V1::EmployeePresencePoliciesController, type: :controller do
  include_context 'shared_context_headers'
  include_context 'shared_context_timecop_helper'

  let(:presence_policy) { create(:presence_policy, account: account) }
  let(:employee) { create(:employee, account: Account.current) }

  describe 'GET #index' do
    subject { get :index, presence_policy_id: presence_policy.id }

    let(:new_policy) { create(:presence_policy, account: account) }
    let!(:employee_presence_policy) do
      create(:employee_presence_policy, employee: employee, effective_at: Date.today)
    end
    let!(:employee_presence_policies) do
      today = Date.today
      [today + 3.days, today + 4.days, today + 5.days].map do |day|
        create(:employee_presence_policy,
          presence_policy: presence_policy, employee: employee, effective_at: day
        )
      end
    end

    context 'with valid params' do
      it { is_expected.to have_http_status(200) }

      context 'response' do
        before { subject }

        it { expect_json_sizes(3) }
        it { expect(response.body).to_not include (employee_presence_policy.id) }
        it { expect_json('2', effective_till: nil, id: employee.id) }
        it { expect_json('1', effective_till: (employee_presence_policies.last.effective_at - 1.day).to_s) }
        it { expect_json('0', effective_till: (employee_presence_policies.second.effective_at - 1.day).to_s) }
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

    context 'with invalid params' do
      context 'with invalid presence_policy' do
        subject { get :index, presence_policy_id: '1' }

        it { is_expected.to have_http_status(404) }
      end

      context 'when presence policy does not belongs to current account' do
        before { Account.current = create(:account) }

        it { is_expected.to have_http_status(404) }
      end

      context 'when current account is not account manager' do
        before { Account::User.current.update!(account_manager: false) }

        it { is_expected.to have_http_status(403) }
      end
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

        it { expect_json(id: employee.id, effective_till: nil) }
        it '' do
          expect_json_keys([
            :id,
            :type,
            :assignation_type,
            :effective_at,
            :assignation_id,
            :order_of_start_day,
            :effective_till
          ])
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

      context 'when current user is not account manager' do
        before { Account::User.current.update!(account_manager: false) }

        it { expect { subject }.to_not change { employee.employee_presence_policies.count } }
        it { is_expected.to have_http_status(403) }
      end
    end
  end
end
