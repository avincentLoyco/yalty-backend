require 'rails_helper'

RSpec.describe API::V1::SettingsController, type: :controller do
  let(:account) { user.account }
  let(:user) { FactoryGirl.create(:account_user) }
  let(:settings_json) do
    {
      "data": {
        "id": "20",
        "type": "settings",
        "attributes": {
          "company-name": "My Company",
          "subdomain": "my-company-946",
          "timezone": "Europe/Madrid",
          "default-locale": "en"
        }
      }
    }
  end

  before(:each) do
    Account.current = account
    @request.headers.merge!(
      'CONTENT-TYPE' => 'application/vnd.api+json',
      'ACCEPT' => 'application/vnd.api+json'
    )
  end

  context 'GET #index' do
    it 'should response with success' do
      get :show

      expect(response).to have_http_status(:success)
    end

    it 'should return only current account' do
      get :show

      data = JSON.parse(response.body)
      expect(data.size).to eq(1)
    end
  end

  context 'PUT #update' do
    it "should update" do
      put :update, settings_json
      expect(response).to have_http_status(:success)
    end
  end
end
