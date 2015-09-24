require 'rails_helper'

RSpec.describe API::V1::SettingsController, type: :controller do
  include_context 'shared_context_headers'

  let(:settings_json) do
    {
      "data": {
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

  context 'GET #show' do
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

    it "should not update when timezone is not valid" do
      settings_json[:data][:attributes][:timezone] = 'abc'

      put :update, settings_json
      expect(response).to have_http_status(422)
    end

    it 'should not update when there is no params' do
      put :update, {}
      expect(response).to have_http_status(400)
    end
  end

  context 'POST #create' do
    it 'should not be routable' do
      expect(:post => "/api/v1/settings").not_to be_routable
    end
  end

  context 'DELETE #delete' do
    it 'should not be routable' do
      expect(:delete => "/api/v1/settings/#{account.id}").not_to be_routable
    end
  end
end
