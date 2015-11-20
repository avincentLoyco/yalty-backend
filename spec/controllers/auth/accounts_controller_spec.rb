require 'rails_helper'

RSpec.describe Auth::AccountsController, type: :controller do
  let(:redirect_uri) { 'http://yalty.test/setup'}
  let(:client) { FactoryGirl.create(:oauth_client, redirect_uri: redirect_uri) }

  before(:each) do
    ENV['YALTY_OAUTH_ID'] = client.uid
    ENV['YALTY_OAUTH_SECRET'] = client.secret
  end

  describe 'POST #create' do
    let(:registration_key) { create(:registration_key) }
    let(:token) { registration_key.token }
    let(:params) do
      {
        account:
          {
            company_name: 'The Company'
          },
        user:
          {
            email: 'test@test.com',
            password: '12345678'
          },
        registration_key:
          {
            token: token
          }
      }
    end

    subject { post :create, params }

    context 'with valid params' do
      it { expect { subject }.to change(Account, :count).by(1)  }
      it { expect { subject }.to change(Account::User, :count).by(1)  }
      it { expect { subject }.to change { registration_key.reload.account } }

      it { is_expected.to have_http_status(:found) }
    end

    context 'with invalid params' do
      context 'when token not send' do
        before { params.tap { |param| param.delete(:registration_key) } }

        it { expect { subject }.to raise_exception(ActionController::ParameterMissing) }
      end

      context 'when token used' do
        let(:used_key) { create(:registration_key, :with_account) }
        let(:token) { used_key }

        it { expect { subject }.to raise_exception(ActiveRecord::RecordNotFound) }
      end

      context 'when token invalid' do
        let(:token) { 'abc' }

        it { expect { subject }.to raise_exception(ActiveRecord::RecordNotFound) }
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
  end
end
