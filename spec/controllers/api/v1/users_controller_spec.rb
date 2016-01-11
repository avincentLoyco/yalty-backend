require 'rails_helper'

RSpec.describe API::V1::UsersController, type: :controller do
  include_context 'shared_context_headers'

  let(:employee) { create(:employee, account: account) }
  let(:employee_id) { employee.id }

  describe 'POST #create' do
    let(:email) { 'test@example.com' }
    let(:password) { '12345678' }
    let(:account_manager) { true }
    let(:params) do
      {
        email: email,
        password: password,
        account_manager: account_manager,
        employee: { id: employee_id }
      }
    end

    subject { post :create, params }

    context 'with valid data' do
      it { expect { subject }.to change { Account::User.count }.by(1) }
      it { is_expected.to have_http_status(201) }

      context 'response body' do
        before { subject }

        it { expect_json_keys(:email, :account_manager, :is_employee, :employee) }
      end

      context 'assign employee' do
        it { expect { subject }.to change { employee.reload.account_user_id } }
      end

      context 'without employee id' do
        before do
          params.delete(:employee)
        end

        it { is_expected.to have_http_status(201) }
        it { expect { subject }.to change { Account::User.count }.by(1) }

        context 'with blank id' do
          it { expect { subject }.to_not change { employee.reload.account_user_id } }
        end
      end

      context 'without password' do
        before do
          params.delete(:password)
        end

        it { expect { subject }.to change { Account::User.count }.by(1) }
        it { is_expected.to have_http_status(201) }
      end

      context 'should send email notification' do
        it { expect { subject }.to change { ActionMailer::Base.deliveries.count }.by(1) }
      end
    end

    context 'with invalid data' do
      context 'without email' do
        let!(:email) { '' }

        it { expect { subject }.to_not change { Account::User.count } }
        it { is_expected.to have_http_status(422) }
      end

      context 'with invalid employee id' do
        let(:employee_id) { 1234 }

        it { expect { subject }.to_not change {  Account::User.count } }
        it { is_expected.to have_http_status(404) }
      end

      context 'with empty employee id' do
        let(:employee_id) { nil }

        it { expect { subject }.to_not change {  Account::User.count } }
        it { is_expected.to have_http_status(422) }
      end
    end
  end

  describe 'GET #index' do
    let!(:users) { create_list(:account_user, 3, account: Account.current) }

    subject { get :index }

    context 'user list' do
      before { subject }

      it { expect_json_sizes(users.count + 1) }
      it { is_expected.to have_http_status(200) }
    end
  end

  describe 'GET #show' do
    let!(:users) { create_list(:account_user, 3, account: Account.current) }
    let(:params) {{ id: users.first.id}}

    subject { get :show, params }

    context 'show user' do
      before { subject }

      it { is_expected.to have_http_status(200) }
    end
  end

  describe 'PUT #update' do
    let!(:users) { create_list(:account_user, 3, account: Account.current) }
    let(:email) { 'test123@example.com' }
    let(:account_manager) { true }
    let(:params) do
      {
        id: users.first.id,
        email: email,
        account_manager: account_manager,
        employee: { id: employee_id }
      }
    end

    subject { put :update, params }

    context 'with valid data' do
      it { expect { subject }.to_not change { Account::User.count } }
      it { is_expected.to have_http_status(204) }
      it { expect { subject }.to change { users.first.reload.email } }

      context 'assign employee' do
        it { expect { subject }.to change { employee.reload.account_user_id } }
      end

      context 'without employee id' do
        before do
          params.delete(:employee)
        end

        it { is_expected.to have_http_status(204) }
        it { expect { subject }.to_not change { Account::User.count } }

        context 'with blank id' do
          it { expect { subject }.to_not change { employee.reload.account_user_id } }
        end
      end
    end


  end
end
