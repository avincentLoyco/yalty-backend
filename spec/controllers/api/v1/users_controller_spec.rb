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

  describe 'PUT #update' do

  end
end
