require "rails_helper"

RSpec.describe API::V1::UsersController, type: :controller do
  include_context "shared_context_headers"

  let!(:user) { create(:account_user, account: account, role: "account_owner") }
  let(:redirect_uri) { "http://yalty.test/setup"}
  let(:client) { FactoryGirl.create(:oauth_client, redirect_uri: redirect_uri) }
  let(:employee) { user.employee }
  let(:employee_id) { employee.id }
  let(:unassiagned_employee) { create(:employee, account: account) }


  before(:each) do
    ENV["YALTY_OAUTH_ID"] = client.uid
    ENV["YALTY_OAUTH_SECRET"] = client.secret
  end

  describe "POST #create" do
    let(:email) { "test@example.com" }
    let(:locale) { "en" }
    let(:password) { "12345678" }
    let(:balance_in_hours) { false }
    let(:role) { "account_administrator" }
    let(:employee) { create(:employee, account: account) }
    let(:params) do
      {
        email: email,
        locale: locale,
        password: password,
        role: role,
        balance_in_hours: balance_in_hours,
        employee: { id: employee_id },
      }
    end

    subject { post :create, params }

    context "with valid data" do
      it { expect { subject }.to change { Account::User.count }.by(1) }
      it { is_expected.to have_http_status(201) }

      context "response body" do
        before { subject }

        it { expect_json_keys(:email, :role, :employee) }
      end

      it "should send email with generated login url" do
        expect { subject }.to change(ActionMailer::Base.deliveries, :count)

        expect(ActionMailer::Base.deliveries.last.body).to match(/http.+code=.+/i)
      end

      context "assign employee" do
        it { expect { subject }.to change { employee.reload.account_user_id } }
      end

      context "without employee id" do
        before do
          params.delete(:employee)
        end

        it { is_expected.to have_http_status(422) }
        it { expect { subject }.to_not change { Account::User.count } }
        it { expect { subject }.to_not change { employee.reload.account_user_id } }
      end

      context "without optional params" do
        before do
          params.delete(:role)
        end

        it { is_expected.to have_http_status(201) }
        it { expect { subject }.to change { Account::User.count }.by(1) }
      end

      context "with null employee" do
        before { params[:employee] = nil }

        it { is_expected.to have_http_status(422) }
        it { expect { subject }.to_not change { Account::User.count } }
      end

      context "without password" do
        before do
          params.delete(:password)
        end

        it { expect { subject }.to change { Account::User.count }.by(1) }
        it { is_expected.to have_http_status(201) }

        it "expect to add generated login url to email" do
          expect(subject).to have_http_status(:created)
          expect(ActionMailer::Base.deliveries.last.body).to match(/http.+code=.+/i)
        end
      end

      context "should send email notification" do
        it { expect { subject }.to change { ActionMailer::Base.deliveries.count }.by(1) }
      end
    end

    context "with invalid data" do
      context "without email" do
        let!(:email) { "" }

        it { expect { subject }.to_not change { Account::User.count } }
        it { is_expected.to have_http_status(422) }
      end

      context "with invalid employee id" do
        let(:employee_id) { 1234 }

        it { expect { subject }.to_not change {  Account::User.count } }
        it { is_expected.to have_http_status(404) }
      end

      context "with empty employee id" do
        let(:employee_id) { nil }

        it { expect { subject }.to_not change {  Account::User.count } }
        it { is_expected.to have_http_status(422) }
      end
    end
  end

  describe "GET #index" do
    let!(:users) { create_list(:account_user, 3, account: account) }

    subject { get :index }

    context "user list" do
      before { subject }

      it { expect_json_sizes(users.count + 1) }
      it { is_expected.to have_http_status(200) }
    end

    it "should return the users for the current account" do
      subject

      users.each do |user|
        expect(response.body).to include user[:id]
      end
    end

    it "should not be visible in context of other account" do
      Account.current = create(:account)
      subject

      users.each do |user|
        expect(response.body).to_not include user[:id]
      end
    end

    it "should not include yalty user" do
      user = create(:account_user, :with_yalty_role, account: account)
      subject

      expect(response.body).to_not include user[:id]
    end
  end

  describe "GET #show" do
    let!(:users) { create_list(:account_user, 3, account: account) }
    let(:params) { { id: user.id } }

    subject { get :show, params }

    context "response body" do
      before { subject }

      it { is_expected.to have_http_status(200) }

      it do
        expect_json_keys(
          [:id, :type, :email, :locale, :role, :balance_in_hours, :employee, :referral_token]
        )
      end
      it do
        expect_json(
          email: user.email, id: user.id, type: "account_user", locale: "en", balance_in_hours: false
        )
      end

      context "when locale is set" do
        let(:user) { create(:account_user, account: account, locale: "fr") }

        it { expect_json(locale: "fr") }
      end

      context "when balance_in_hours is true" do
        let(:user) { create(:account_user, account: account, balance_in_hours: true) }

        it { expect_json(balance_in_hours: true) }
      end

      context "when is an employee" do
        let(:user) { create(:account_user, account: account) }

        it { expect_json_keys("employee", [:id, :type]) }
      end
    end
  end

  describe "PUT #update" do
    let!(:users) { create_list(:account_user, 3, account: account) }
    let(:email) { "test123@example.com" }
    let(:role) { user.role }
    let(:balance_in_hours) { true }
    let(:locale) { "fr" }
    let(:params) do
      {
        id: user.id,
        email: email,
        role: role,
        locale: locale,
        employee: { id: user.employee&.id },
        balance_in_hours: balance_in_hours,
      }
    end

    subject { put :update, params }

    context "with valid data" do
      it { expect { subject }.to_not change { Account::User.count } }
      it { is_expected.to have_http_status(204) }
      it { expect { subject }.to change { user.reload.email } }
      it { expect { subject }.to change { user.reload.locale } }
      it { expect { subject }.to change { user.reload.balance_in_hours } }

      context "assign another employee" do
        before do
          params[:employee] = {
            id: unassiagned_employee.id,
          }
        end

        it { is_expected.to have_http_status(204) }
        it { expect { subject }.to change { unassiagned_employee.reload.account_user_id } }
      end

      context "account owner can change role when he is not last" do
        before { users.last.update(role: "account_owner") }
        let(:user_id) { user.id }
        let(:role) { "user" }

        it { is_expected.to have_http_status(204) }
        it { expect { subject }.to change { user.reload.role } }
      end

      context "can't change last account owner" do
        let(:user_id) { user.id }

        %w(account_administrator user).each do |new_role|
          let(:role) { new_role }

          it { is_expected.to have_http_status(422) }
          it { expect { subject }.not_to change { user.reload.role } }

          context "response" do
            before { subject }

            it { expect_json(regex("last account owner cannot change role")) }
          end
        end
      end

      context "that remove employee" do
        before do
          params[:employee] = nil
        end

        it { is_expected.to have_http_status(422) }
        it { expect { subject }.to_not change { employee.reload.account_user_id } }
      end

      context "with password and existing password" do
        before do
          params[:password_params] =  {
            old_password: "1234567890",
            password: "newlongpassword",
            password_confirmation: "newlongpassword",
          }
        end

        let(:user) { create(:account_user, account: account, password: "1234567890") }

        it { is_expected.to have_http_status(204) }
        it { expect { subject }.to change { user.reload.password_digest } }
      end

      context "with password without existing password" do
        before do
          params[:password_params] =  {
            password: "newlongpassword",
            password_confirmation: "newlongpassword",
          }
        end

        let(:user) { create(:account_user, account: account, password: "1234567890") }

        it { is_expected.to have_http_status(204) }
        it { expect { subject }.to change { user.reload.password_digest } }
      end

      context "with role" do
        context "when administrator" do
          let(:user) { create(:account_user, account: account, role: "account_administrator") }
          let(:other_user) { users.last }

          before do
            other_user.update!(role: "user")
            params[:id] = other_user.id
            params[:role] = "account_administrator"
          end

          it { is_expected.to have_http_status(204) }
          it { expect { subject }.to change { other_user.reload.role } }
        end

        xcontext "when user" do
          let(:user) { create(:account_user, account: account, role: "user") }

          before do
            params[:role] = "account_administrator"
          end

          it { is_expected.to have_http_status(403) }
          it { expect { subject }.to_not change { user.reload.role } }
        end
      end
    end

    context "with yalty user" do
      let(:user) { create(:account_user, :with_yalty_role, account: account, password: "1234567890") }
      let(:email) { user.email }
      let(:role) { "yalty" }
      let(:locale) { nil }

      before do
        params.delete(:employee)
      end

      describe "when email changes" do
        let(:email) { "test123@example.com" }

        it { is_expected.to have_http_status(422) }
        it { expect { subject }.to_not change { user.reload.attributes } }
      end

      describe "when role changes" do
        let(:role) { "user" }

        it { is_expected.to have_http_status(422) }
        it { expect { subject }.to_not change { user.reload.attributes } }
      end

      describe "when employee is assigned" do
        before do
          params[:employee] = {
            id: unassiagned_employee.id,
          }
        end

        it { is_expected.to have_http_status(422) }
        it { expect { subject }.to_not change { user.reload.attributes } }
        it { expect { subject }.to_not change { unassiagned_employee.reload.account_user_id } }
      end

      describe "when password changes" do
        before do
          params[:password_params] =  {
            old_password: "1234567890",
            password: "newlongpassword",
            password_confirmation: "newlongpassword",
          }
        end

        it { is_expected.to have_http_status(422) }
        it { expect { subject }.to_not change { user.reload.attributes } }
      end

      describe "when authorized attributes change" do
        let(:locale) { "fr" }

        it { is_expected.to have_http_status(204) }
        it { expect { subject }.to change { user.reload.locale } }
      end
    end
  end

  context "DELETE #destroy" do
    subject { delete :destroy, id: user.id }
    let!(:users) { create_list(:account_user, 3, account: account) }

    context "cannot delete last account owner" do
      it { is_expected.to have_http_status(403) }
      it { expect { subject }.to_not change { Account::User.count } }

      context "response" do
        before { subject }

        it { expect_json(regex("last account owner cannot be deleted")) }
      end
    end

    context "can delete account owner when he is not last" do
      before { users.last.update(role: "account_owner") }
      it { is_expected.to have_http_status(204) }
      it { expect { subject }.to change { Account::User.count } }
    end
  end
end
