require 'rails_helper'

RSpec.describe API::V1::UsersController, type: :controller do
  include_context 'shared_context_headers'

  let(:user) { create(:account_user, role: 'account_owner') }
  let(:redirect_uri) { 'http://yalty.test/setup'}
  let(:client) { FactoryGirl.create(:oauth_client, redirect_uri: redirect_uri) }
  let(:employee) { create(:employee, account: account) }
  let(:employee_id) { employee.id }

  before(:each) do
    ENV['YALTY_OAUTH_ID'] = client.uid
    ENV['YALTY_OAUTH_SECRET'] = client.secret
  end

  describe 'POST #create' do
    let(:email) { 'test@example.com' }
    let(:locale) { 'en' }
    let(:password) { '12345678' }
    let(:role) { 'account_administrator' }
    let(:params) do
      {
        email: email,
        locale: locale,
        password: password,
        role: role,
        employee: { id: employee_id }
      }
    end

    subject { post :create, params }

    context 'with valid data' do
      it { expect { subject }.to change { Account::User.count }.by(1) }
      it { is_expected.to have_http_status(201) }

      context 'response body' do
        before { subject }

        it { expect_json_keys(:email, :role, :employee) }
      end

      it 'should send email with generated login url' do
        expect { subject }.to change(ActionMailer::Base.deliveries, :count)

        expect(ActionMailer::Base.deliveries.last.body).to match(/http.+code=.+/i)
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

      context 'without optional params' do
        before do
          params.delete(:role)
          params.delete(:employee)
        end

        it { is_expected.to have_http_status(201) }
        it { expect { subject }.to change { Account::User.count }.by(1) }
      end

      context 'with null employee' do
        before { params[:employee] = nil }

        it { is_expected.to have_http_status(201) }
        it { expect { subject }.to change { Account::User.count }.by(1) }
      end

      context 'without password' do
        before do
          params.delete(:password)
        end

        it { expect { subject }.to change { Account::User.count }.by(1) }
        it { is_expected.to have_http_status(201) }

        it 'expect to add generated login url to email' do
          expect(subject).to have_http_status(:created)
          expect(ActionMailer::Base.deliveries.last.body).to match(/http.+code=.+/i)
        end
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

    it 'should return the users for the current account' do
      subject

      users.each do |user|
        expect(response.body).to include user[:id]
      end
    end

    it 'should not be visible in context of other account' do
      Account.current = create(:account)
      subject

      users.each do |user|
        expect(response.body).to_not include user[:id]
      end
    end
  end

  describe 'GET #show' do
    let!(:users) { create_list(:account_user, 3, account: account) }
    let(:params) { { id: user.id } }

    subject { get :show, params }

    context 'response body' do
      before { subject }

      it { is_expected.to have_http_status(200) }

      it { expect_json_keys([:id, :type, :email, :locale, :role, :employee, :referral_token]) }
      it { expect_json(email: user.email, id: user.id, type: 'account_user', locale: nil) }

      context 'when locale is set' do
        let(:user) { create(:account_user, locale: 'en') }

        it { expect_json(locale: 'en') }
      end

      context 'when is an employee' do
        let(:user) { create(:account_user, :with_employee) }

        it { expect_json_keys('employee', [:id, :type]) }
      end
    end
  end

  describe 'PUT #update' do
    let!(:users) { create_list(:account_user, 3, account: Account.current) }
    let(:email) { 'test123@example.com' }
    let(:locale) { 'en' }
    let(:role) { user.role }
    let(:params) do
      {
        id: user.id,
        email: email,
        role: role,
        locale: locale
      }
    end

    subject { put :update, params }

    context 'with valid data' do
      it { expect { subject }.to_not change { Account::User.count } }
      it { is_expected.to have_http_status(204) }
      it { expect { subject }.to change { user.reload.email } }
      it { expect { subject }.to change { user.reload.locale } }

      context 'assign employee' do
        before do
          params[:employee] = {
            id: employee.id
          }
        end

        it { is_expected.to have_http_status(204) }
        it { expect { subject }.to change { employee.reload.account_user_id } }
      end

      context 'account owner can change role when he is not last' do
        before { users.last.update(role: 'account_owner') }
        let(:user_id) { user.id }
        let(:role) { 'user' }

        it { is_expected.to have_http_status(204) }
        it { expect { subject }.to change { user.reload.role } }
      end

      context "can't change last account owner" do
        let(:user_id) { user.id }

        %w(account_administrator user).each do |new_role|
          let(:role) { new_role }

          it { is_expected.to have_http_status(422) }
          it { expect { subject }.not_to change { user.reload.role } }

          context 'response' do
            before { subject }

            it { expect_json(regex('last account owner cannot change role')) }
          end
        end
      end

      context 'without employee id' do
        it { is_expected.to have_http_status(204) }
        it { expect { subject }.to_not change { employee.reload.account_user_id } }
      end

      context 'that remove employee' do
        before do
          params[:employee] = nil
        end

        let(:user) { create(:account_user, :with_employee) }
        let(:employee) { user.employee }

        it { is_expected.to have_http_status(204) }
        it { expect { subject }.to change { employee.reload.account_user_id } }
      end

      context 'with password' do
        before do
          params[:password_params] =  {
            old_password: '1234567890',
            password: 'newlongpassword',
            password_confirmation: 'newlongpassword',
          }
        end

        let(:user) { create(:account_user, password: '1234567890') }

        it { is_expected.to have_http_status(204) }
        it { expect { subject }.to change { user.reload.password_digest } }
      end

      context 'with role' do
        context 'when administrator' do
          let(:user) { create(:account_user, role: 'account_administrator') }
          let(:other_user) { users.last }

          before do
            other_user.update!(role: 'user')
            params[:id] = other_user.id
            params[:role] = 'account_administrator'
          end

          it { is_expected.to have_http_status(204) }
          it { expect { subject }.to change { other_user.reload.role } }
        end

        xcontext 'when user' do
          let(:user) { create(:account_user, role: 'user') }

          before do
            params[:role] = 'account_administrator'
          end

          it { is_expected.to have_http_status(403) }
          it { expect { subject }.to_not change { user.reload.role } }
        end
      end
    end
  end

  context 'DELETE #destroy' do
    subject { delete :destroy, id: user.id }
    let!(:users) { create_list(:account_user, 3, account: Account.current) }

    context 'cannot delete last account owner' do
      it { is_expected.to have_http_status(403) }
      it { expect { subject }.to_not change { Account::User.count } }

      context 'response' do
        before { subject }

        it { expect_json(regex('last account owner cannot be deleted')) }
      end
    end

    context 'can delete account owner when he is not last' do
      before { users.last.update(role: 'account_owner') }
      it { is_expected.to have_http_status(204) }
      it { expect { subject }.to change { Account::User.count } }
    end
  end
end
