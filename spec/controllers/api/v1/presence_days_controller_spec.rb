require 'rails_helper'

RSpec.describe API::V1::PresenceDaysController, type: :controller do
  include_examples 'example_authorization',
    resource_name: 'presence_day'
  include_context 'shared_context_headers'

  let(:presence_policy) { create(:presence_policy, account: account) }

  shared_examples 'Employee Balances Update' do
    context 'when there are no employees affected by the policy' do
      it { is_expected.to have_http_status(204) }
    end

    context 'when there is employee affected by policy' do
      let(:employee) do
        create(:employee, :with_time_offs, account: account, presence_policy: presence_policy)
      end
      let(:f_time_off) { employee.time_offs.first }
      let(:s_time_off) { employee.time_offs.second }
      let(:t_time_off) { employee.time_offs.last }

      context 'and he does not have related balances' do
        it { is_expected.to have_http_status(204) }
      end

      context 'and he has related balances' do
        it { expect { subject }.to change { f_time_off.employee_balance.reload.beeing_processed } }
        it { expect { subject }.to change { s_time_off.employee_balance.reload.beeing_processed } }
        it { expect { subject }.to change { t_time_off.employee_balance.reload.beeing_processed } }

        it { is_expected.to have_http_status(204) }
      end
    end
  end

  describe 'GET #show' do
    let(:presence_day) { create(:presence_day, presence_policy: presence_policy) }
    subject { get :show, params }

    context 'with valid data' do
      let(:params) {{ id: presence_day.id, presence_policy_id: presence_policy.id }}

      it { is_expected.to have_http_status(200) }

      context 'response body' do
        before { subject }

        it { expect_json_keys([:order, :id, :minutes]) }
      end
    end

    context 'with invalid data' do
      context 'with invalid id' do
        let(:params) {{ id: '2', presence_policy_id: presence_policy.id }}

        it { is_expected.to have_http_status(404) }
      end

      context 'with not users presence day' do
        let(:params) {{ id: presence_day.id, presence_policy_id: presence_policy.id }}
        before(:each) do
          user = create(:account_user)
          Account.current = user.account
        end

        it { is_expected.to have_http_status(404) }
      end
    end
  end

  describe 'GET #index' do
    let!(:presence_days) { create_list(:presence_day, 2, presence_policy: presence_policy) }
    subject { get :index, presence_policy_id: presence_policy.id }

    context 'with account presence days' do
      before { subject }

      it { expect_json_sizes(2) }
      it { is_expected.to have_http_status(200) }
    end

    context 'with not accounts presence policy' do
      before(:each) do
        user = create(:account_user)
        Account.current = user.account
      end

      it { is_expected.to have_http_status(404) }
    end

    context 'with invalid presence policy id' do
      subject { get :index, presence_policy_id: '1' }

      it { is_expected.to have_http_status(404) }
    end
  end

  describe 'POST #create' do
    subject { post :create, params }
    let(:order) { '1' }
    let(:presence_policy_id) { presence_policy.id.to_s }
    let(:params) do
      {
        presence_policy: {
          id: presence_policy_id,
          type: 'presence_policy'
        },
        order: order,
        type: 'presence_day'
      }
    end

    context 'with valid data' do
      it { is_expected.to have_http_status(201) }
      it { expect { subject }.to change { PresenceDay.count }.by(1) }
      it { expect { subject }.to change { presence_policy.reload.presence_days.count }.by(1) }

      context 'response' do
        before { subject }

        it { expect_json_keys([:id, :type, :order, :minutes]) }
      end
    end

    context 'with invalid data' do
      context 'with invalid presence_policy_id' do
        let(:presence_policy_id) { '1' }

        it { is_expected.to have_http_status(404) }
        it { expect { subject }.to_not change { PresenceDay.count } }
        it { expect { subject }.to_not change { presence_policy.reload.presence_days.count } }
      end

      context 'with presence policy which belongs to other account' do
        let(:second_presence_policy) { create(:presence_policy) }
        let(:presence_policy_id) { second_presence_policy.id.to_s }

        it { is_expected.to have_http_status(404) }
        it { expect { subject }.to_not change { PresenceDay.count } }
        it { expect { subject }.to_not change { presence_policy.reload.presence_days.count } }
      end

      context 'without required attributes' do
        let(:missing_params) { params.tap { |params| params.delete(:order) } }
        subject { post :create, missing_params }

        it { is_expected.to have_http_status(422) }
        it { expect { subject }.to_not change { PresenceDay.count } }
        it { expect { subject }.to_not change { presence_policy.reload.presence_days.count } }

        context 'response' do
          before { subject }

          it { expect_json(regex('missing')) }
        end
      end

      context 'with data that do not pass validation' do
        before { presence_policy.presence_days.create(params.except(:type, :presence_policy)) }

        it { is_expected.to have_http_status(422) }
        it { expect { subject }.to_not change { PresenceDay.count } }
        it { expect { subject }.to_not change { presence_policy.reload.presence_days.count } }

        context 'response' do
          before { subject }

          it { expect_json(regex('has already been taken')) }
        end
      end
    end
  end

  describe 'PUT #update' do
    let(:presence_day) { create(:presence_day, presence_policy: presence_policy) }
    let(:id) { presence_day.id.to_s }
    let(:order) { '1' }
    let(:presence_policy_id) { presence_policy.id.to_s }
    let(:params) do
      {
        id: id,
        order: order,
        type: 'presence_day'
      }
    end

    subject { put :update, params }

    context 'with valid params' do
      it { expect { subject }.to change { presence_day.reload.order } }

      it_behaves_like 'Employee Balances Update'
    end

    context 'with invalid params' do
      context 'with invalid presence day id' do
        let(:id) { '1' }

        it { expect { subject }.to_not change { presence_day.reload.order } }
        it { is_expected.to have_http_status(404) }
      end

      context 'without required params' do
        let(:missing_params) { params.tap { |params| params.delete(:order) } }
        subject { put :update, missing_params }

        it { expect { subject }.to_not change { presence_day.reload.order } }
        it { is_expected.to have_http_status(422) }

        context 'response' do
          before { subject }

          it { expect_json(regex('missing')) }
        end
      end

      context 'with data that do not pass validation' do
        before { presence_policy.presence_days.create(params.except(:type, :id)) }

        it { expect { subject }.to_not change { presence_day.reload.order } }
        it { is_expected.to have_http_status(422) }

        context 'response' do
          before { subject }

          it { expect_json(regex('has already been taken')) }
        end
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:presence_day) { create(:presence_day, presence_policy: presence_policy) }
    subject { delete :destroy, params }

    context 'with valid id' do
      let(:params) {{ id: presence_day.id, presence_policy_id: presence_policy.id }}

      it { expect { subject }.to change { PresenceDay.count }.by(-1) }
      it { is_expected.to have_http_status(204) }

      it_behaves_like 'Employee Balances Update'
    end

    context 'with invalid id' do
      let(:params) {{ id: '1', presence_policy_id: presence_policy.id }}

      it { expect { subject }.to_not change { PresenceDay.count } }
      it { is_expected.to have_http_status(404) }
    end
  end
end
