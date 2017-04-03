require 'rails_helper'

RSpec.describe Auth::AccountsController, type: :controller do
  let(:redirect_uri) { 'http://yalty.test/setup'}
  let(:client) { FactoryGirl.create(:oauth_client, redirect_uri: redirect_uri) }

  before(:each) do
    ENV['YALTY_OAUTH_ID'] = client.uid
    ENV['YALTY_OAUTH_SECRET'] = client.secret
  end

  describe 'POST #create' do
    let(:company_name) { 'The Company' }
    let(:params) do
      {
        account:
          {
            company_name: company_name,
            default_locale: 'en'
          },
        user:
          {
            email: 'test@test.com'
          }
      }
    end

    subject { post :create, params }

    context 'with valid params' do
      it { expect { subject }.to change(Account, :count).by(1)  }
      it { expect { subject }.to change(Account::User, :count).by(1)  }

      it { is_expected.to have_http_status(:found) }

      it 'should send email with account url' do
        expect do
          post :create, params
        end.to change(ActionMailer::Base.deliveries, :count)

        expect(ActionMailer::Base.deliveries.last.body).to match(/https?:\/\/the-company/i)
      end

      context 'with referred_by key' do
        let!(:referrer_1) { create(:referrer, email: 'test@test.com') }
        let!(:referrer_2) { create(:referrer, email: 'not_test@example.com') }
        before { params[:account][:referred_by] = referrer_2.token }
        it { expect { subject }.to change(referrer_2.referred_accounts, :count).by(1) }
      end

      context 'where Referrer does not exists' do
        let(:user) { create(:account_user) }
        before do
          params[:account][:referred_by] = user.referrer.token
          params[:user][:email] = 'someRandomEmail@random.com'
        end

        it { expect { subject }.to change(user.referrer.referred_accounts, :count).by(1) }
        it { expect { subject }.to change(Account::User, :count).by(1) }
        it { expect { subject }.to change(Account, :count).by(1) }
      end

      context 'with nil as referred_by key' do
        before do
          params[:account][:referred_by] = nil
          params[:user][:email] = 'someRandomEmail@random.com'
        end

        it { expect { subject }.to change(Account::User, :count).by(1) }
        it { expect { subject }.to change(Account, :count).by(1) }
      end

      context 'with empty string as referred_by key' do
        before do
          params[:account][:referred_by] = ''
          params[:user][:email] = 'someRandomEmail@random.com'
        end

        it { expect { subject }.to change(Account::User, :count).by(1) }
        it { expect { subject }.to change(Account, :count).by(1) }
      end
     end

    context 'with invalid params' do
      context 'with own referral token' do
        let(:user) { create(:account_user) }
        before do
          params[:account][:referred_by] = user.referrer.token
          params[:user][:email] = user.email
          subject
        end

        it { expect(response.status).to eq(422) }
        it { expect(response.body).to include('can\'t use own referral token') }
      end

      context 'when params are missing' do
        shared_examples 'Missing param' do
          it { expect { subject }.to_not change { Account.count } }
          it { expect { subject }.to_not change { Account::User.count } }

          it { is_expected.to have_http_status(422) }
        end

        context 'when user params not send' do
          before { params.tap { |param| param.delete(:user) } }

          it_behaves_like 'Missing param'
        end

        context 'when account params not send' do
          before { params.tap { |param| param.delete(:account) } }

          it_behaves_like 'Missing param'
        end
      end
    end

    context 'ACCEPT: application/json' do
      let(:params) { super().merge({format: 'json'}) }

      context 'response' do
        before { subject }

        it { expect(response).to have_http_status(:created) }
        it { expect_json_keys(:code) }
        it { expect_json_keys(:redirect_uri) }
        it { expect_json(redirect_uri: regex(%r{^http://.+\.yalty.test/setup})) }
      end
    end

    context 'ACCEPT: */*' do
      let(:params) { super().merge({format: nil}) }

      context 'response' do
        before { subject }

        it { expect(response).to be_redirect }
        it { expect(response.location).to match(%r{^http://.+\.yalty.test/setup}) }
      end
    end

    context 'POST #list' do
      subject { post :list, email: email }
      let(:email) { 'test@test.com' }

      context 'when user with given email does not exist' do
        it { expect { subject }.to change(ActionMailer::Base.deliveries, :count) }
        it { is_expected.to have_http_status(204) }
      end

      context 'when user with email exist' do
        let!(:user) { create(:account_user, email: email) }

        it { expect { subject }.to change(ActionMailer::Base.deliveries, :count) }
        it { is_expected.to have_http_status(204) }
      end

      context 'when email is missing' do
        let(:email) { nil }

        it { expect { subject }.to_not change(ActionMailer::Base.deliveries, :count) }
        it { is_expected.to have_http_status(422) }
      end
    end
  end
end
