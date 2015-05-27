require 'rails_helper'

RSpec.describe Auth::Accounts::TokensController, type: :controller do
  let(:redirect_uri) { 'http://yalty.test/setup'}
  let!(:client) { FactoryGirl.create(:oauth_client, redirect_uri: redirect_uri) }
  let!(:code) { FactoryGirl.create(:oauth_code, application: client) }

  before(:each) do
    ENV['YALTY_OAUTH_ID'] = client.uid
    ENV['YALTY_OAUTH_SECRET'] = client.secret
    ENV['YALTY_OAUTH_REDIRECT_URI'] = client.redirect_uri
    ENV['YALTY_OAUTH_SCOPES'] = client.scopes.to_s
  end

  describe 'GET #create' do
    let(:params) { Hash(code: code.token) }

    it 'should create token' do
      expect {
        get :create, params

        expect(response).to have_http_status(:success)
      }.to change(client.access_tokens, :count).by(1)
    end

    it 'should destroy code' do
      expect {
        get :create, params

        expect(response).to have_http_status(:success)
      }.to change(client.access_grants, :count).by(-1)
    end

    it 'should contain token' do
      get :create, params

      expect_json_keys(:access_token)
      expect_json_types(access_token: :string)
    end

    it 'should contain token type set to bearer' do
      get :create, params

      expect_json_keys(:token_type)
      expect_json_types(token_type: :string)
      expect_json(token_type: 'bearer')
    end

    it 'should contain expires_in' do
      get :create, params

      expect_json_keys(:expires_in)
      expect_json_types(expires_in: :integer)
    end

    it 'should contain refresh token' do
      get :create, params

      expect_json_keys(:refresh_token)
      expect_json_types(refresh_token: :string)
    end

    it 'should contain created at' do
      get :create, params

      expect_json_keys(:created_at)
      expect_json_types(created_at: :integer)
    end

    it 'should return error whith wrong code' do
      get :create, params.merge(code: 'wrong')

      expect(response).to have_http_status(:unauthorized)
      expect_json_keys(:error)
      expect_json_keys(:error_description)
    end

  end
end
