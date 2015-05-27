require 'rails_helper'

RSpec.describe Auth::AccountsController, type: :controller do
  let(:redirect_uri) { 'http://yalty.test/setup'}
  let(:client) { FactoryGirl.create(:oauth_client, redirect_uri: redirect_uri) }

  before(:each) do
    ENV['YALTY_OAUTH_ID'] = client.uid
    ENV['YALTY_OAUTH_SECRET'] = client.secret
  end

  describe 'POST #create' do
    let(:params) { Hash(account: { company_name: 'The Company' }, user: { email: 'test@test.com', password: '12345678' }) }

    it 'should create account' do
      expect do
        post :create, params
      end.to change(Account, :count).by(1)

      expect(response).to have_http_status(:found)
    end

    it 'should create user' do
      expect do
        post :create, params
      end.to change(Account::User, :count).by(1)

      expect(response).to have_http_status(:found)
    end

    context 'ACCEPT: application/json' do
      let(:params) { super().merge({format: 'json'}) }

      it 'should contain code' do
        post :create, params

        expect(response).to have_http_status(:created)
        expect_json_keys(:code)
      end

      it 'should contain redirect_uri' do
        post :create, params

        expect(response).to have_http_status(:created)
        expect_json_keys(:redirect_uri)
        expect_json(redirect_uri: regex(%r{^http://.+\.yalty.test/setup}))
      end

    end

    context 'ACCEPT: */*' do
      let(:params) { super().merge({format: nil}) }

      it 'should be redirected' do
        post :create, params

        expect(response).to be_redirect
      end

      it 'should be redirected to client redirect uri' do
        post :create, params

        expect(response.location).to match(%r{^http://.+\.yalty.test/setup})
      end
    end
  end
end
