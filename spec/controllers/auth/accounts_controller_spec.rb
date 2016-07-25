require 'rails_helper'

RSpec.describe Auth::AccountsController, type: :controller do
  let(:redirect_uri) { 'http://yalty.test/setup'}
  let(:client) { FactoryGirl.create(:oauth_client, redirect_uri: redirect_uri) }

  before(:each) do
    ENV['YALTY_OAUTH_ID'] = client.uid
    ENV['YALTY_OAUTH_SECRET'] = client.secret
  end

  describe 'POST #create' do
    let(:password) { '12345678' }
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
            email: 'test@test.com',
            password: password
          }
      }
    end

    subject { post :create, params }

    context 'with valid params' do
      it { expect { subject }.to change(Account, :count).by(1)  }
      it { expect { subject }.to change(Account::User, :count).by(1)  }

      it { is_expected.to have_http_status(:found) }

      it 'should send email with credentials' do
        expect do
          post :create, params
        end.to change(ActionMailer::Base.deliveries, :count)

        expect(ActionMailer::Base.deliveries.last.body).to match(/password: .+/i)
      end

      context 'should create account when user has no password' do
        let(:password) { '' }
        let(:company_name) { 'New Company' }

        it { expect { subject }.to change(Account, :count).by(1)  }
        it { expect { subject }.to change(Account::User, :count).by(1)  }

        it { is_expected.to have_http_status(:found) }

        it 'expect to add generated password to email' do
          expect(subject).to have_http_status(:found)
          expect(ActionMailer::Base.deliveries.last.body).to match(/password: .+/i)
        end
      end
    end

    context 'with invalid params' do
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

    context 'GET #list' do
      subject { get :list, email: email }
      let(:email) { 'test@test.com'}

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
        subject { get :list }

        it { expect { subject }.to_not change(ActionMailer::Base.deliveries, :count) }
        it { is_expected.to have_http_status(422) }
      end
    end
  end
end
